// Pane: a Hyprland plugin that gives Quickshell a capture of the screen WITHOUT its own surfaces.
//
// Quickshell draws a live blur of what is behind its bar and popups. It captures the output
// (wlr-screencopy), but the capture contains its own surfaces, so it has to estimate and subtract
// them, which leaves ghosts when the background moves. For captures made by Quickshell, this plugin
// renders the scene again with that client's layer-shell surfaces left out, so the capture is just
// the background. Captures by any other client (grim, OBS, screen sharing) are untouched.
//
// How: `Screenshare::CScreenshareFrame::renderMonitor` normally copies the monitor's finished
// frame into the client's buffer. For a monitor capture by Quickshell it is replaced by drawing
// the monitor scene (the same scene the screen shows: windows, special workspace, other layers) with
// `noScreenShare` set, for the duration of the draw, on the layers that belong to the capturing
// process. `shouldRenderContent` skips such layers while a capture is rendered.
//
// Second job: a late-armed capture request must not wait for the next change. Quickshell asks for a
// new capture after every answer, and the compositor can only take the request when it is not busy
// rendering. If the request lands just after a commit that Quickshell has not seen, nothing else may
// change for a long time, and the glass would show the old picture until it does (100-200 ms seen).
// So when a Quickshell monitor capture is armed after a commit that happened since its last answer,
// one frame is scheduled, and the capture is answered at the next vblank.
//
// This relies on Hyprland internals (private members, an exported but unstable function), so the
// plugin is built against the exact Hyprland package and refuses to load on a version mismatch.
// Quickshell checks the marker file below and falls back to its own estimate when it is missing.

#include <algorithm>
#include <any>
#include <array>
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstdarg>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <deque>
#include <expected>
#include <filesystem>
#include <format>
#include <fstream>
#include <functional>
#include <future>
#include <iomanip>
#include <iostream>
#include <limits>
#include <list>
#include <locale>
#include <map>
#include <memory>
#include <mutex>
#include <numeric>
#include <optional>
#include <queue>
#include <random>
#include <ranges>
#include <regex>
#include <set>
#include <span>
#include <sstream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <thread>
#include <tuple>
#include <type_traits>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <variant>
#include <vector>
#include <unistd.h>
#include <wayland-server-core.h>

// The session and frame classes keep what we need in private members.
#define private public
#define protected public
#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/managers/screenshare/ScreenshareManager.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/render/Context.hpp>
#include <hyprland/src/render/scene/MonitorScene.hpp>
#include <hyprland/src/desktop/state/LayerState.hpp>
#include <hyprland/src/desktop/view/LayerSurface.hpp>
#include <hyprland/src/desktop/rule/layerRule/LayerRuleApplicator.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/helpers/time/Time.hpp>
#undef private
#undef protected

inline HANDLE PHANDLE = nullptr;

namespace {
    using RenderMonitorFn = void (*)(void*, Render::CRenderContext&);

    using OutputCommitFn = void (*)(void*, PHLMONITOR, bool);
    using ShareFn        = Screenshare::eScreenshareError (*)(void*, SP<IHLBuffer>, const CRegion&, Screenshare::FScreenshareCallback);

    CFunctionHook* g_hook       = nullptr;
    CFunctionHook* g_hookCommit = nullptr;
    CFunctionHook* g_hookShare  = nullptr;
    std::string    g_marker;

    // Output commits seen per monitor, and the commit count at which each Quickshell session was
    // last answered. (Only touched from the compositor's main thread.)
    std::unordered_map<const void*, uint64_t> g_commits;
    std::unordered_map<const void*, uint64_t> g_answered;

    // The file Quickshell looks for. It lives in this Hyprland instance's runtime directory, so a
    // stale one from an earlier instance can never be mistaken for a live plugin.
    std::string markerPath() {
        const char* runtime = getenv("XDG_RUNTIME_DIR");
        const char* sig     = getenv("HYPRLAND_INSTANCE_SIGNATURE");
        if (!runtime || !sig)
            return "";
        return std::string(runtime) + "/hypr/" + sig + "/pane-active";
    }

    // Is this process a Quickshell? (Nix wraps it: the executable is `.quickshell-wrapped`.)
    bool isQuickshell(pid_t pid) {
        char buf[512] = {0};
        const auto n  = readlink(("/proc/" + std::to_string(pid) + "/exe").c_str(), buf, sizeof(buf) - 1);
        if (n <= 0)
            return false;
        const std::string_view exe(buf, n);
        const auto             base = exe.substr(exe.rfind('/') == std::string_view::npos ? 0 : exe.rfind('/') + 1);
        return base == ".quickshell-wrapped" || base == "quickshell";
    }

    // Sets noScreenShare on layers for the length of one scene render, and clears it again however
    // the render ends.
    class CLayerHider {
      public:
        void hide(const PHLLS& layer) {
            layer->m_ruleApplicator->noScreenShare().set(true, Desktop::Types::PRIORITY_SET_PROP);
            m_layers.push_back(layer);
        }
        size_t count() const {
            return m_layers.size();
        }
        ~CLayerHider() {
            for (auto const& l : m_layers)
                l->m_ruleApplicator->noScreenShare().unset(Desktop::Types::PRIORITY_SET_PROP);
        }

      private:
        std::vector<PHLLS> m_layers;
    };

    // Draws the monitor scene into the frame's buffer without the capturing client's layers.
    // Returns false if it did not draw anything, so that the original can run.
    bool renderCleanScene(Screenshare::CScreenshareFrame* frame, Render::CRenderContext& ctx) {
        auto* session = frame->m_session.get();
        if (!session || session->m_type != Screenshare::SHARE_MONITOR || !session->m_client || frame->done())
            return false;

        pid_t pid = 0;
        uid_t uid = 0;
        gid_t gid = 0;
        wl_client_get_credentials(session->m_client, &pid, &uid, &gid);
        if (!isQuickshell(pid))
            return false;

        const auto monitor = session->monitor();
        if (!monitor)
            return false;

        CLayerHider hider;
        for (auto const& layer : Desktop::layerState()->layers()) {
            if (layer->getPID() == pid)
                hider.hide(layer);
        }

        // The same set-up the original does for a monitor capture, then the scene instead of the
        // finished frame.
        ctx.m_data.fbSize = frame->m_bufferSize;
        g_pHyprRenderer->setProjectionType(ctx, Render::RPT_EXPORT);
        ctx.m_data.transformDamage = false;
        ctx.m_data.noSimplify      = true;
        g_pHyprRenderer->setViewport(0, 0, frame->m_bufferSize.x, frame->m_bufferSize.y);

        const bool wasCapture  = ctx.m_renderingCapture;
        ctx.m_renderingCapture = true;
        g_pHyprRenderer->startRenderPass(ctx);
        Render::CMonitorScene(monitor).draw(ctx, Time::steadyNow());
        ctx.m_renderingCapture = wasCapture;

        if (g_answered.size() > 64)
            g_answered.clear();
        g_answered[session] = g_commits[monitor.get()];
        return true;
    }

    void hkRenderMonitor(void* self, Render::CRenderContext& ctx) {
        bool done = false;
        try {
            done = renderCleanScene(static_cast<Screenshare::CScreenshareFrame*>(self), ctx);
        } catch (const std::exception& e) {
            // Never take the compositor down for a blur: fall back to the plain capture.
            HyprlandAPI::addNotification(PHANDLE, std::string("[pane] clean capture failed, using the normal one: ") + e.what(), CHyprColor{1.0, 0.5, 0.1, 1.0}, 6000);
        }
        if (!done)
            reinterpret_cast<RenderMonitorFn>(g_hook->m_original)(self, ctx);
    }

    // Counts the commits per monitor, then lets Hyprland answer the pending captures as usual.
    void hkOnOutputCommit(void* self, PHLMONITOR monitor, bool copyFBPrepared) {
        if (monitor)
            g_commits[monitor.get()]++;
        reinterpret_cast<OutputCommitFn>(g_hookCommit->m_original)(self, monitor, copyFBPrepared);
    }

    // A frame was armed for a capture. If the monitor committed since this session was last answered,
    // the client missed it: schedule a frame so that the capture is answered at the next vblank.
    void rescueLateRequest(Screenshare::CScreenshareFrame* frame) {
        auto* session = frame->m_session.get();
        if (!session || session->m_type != Screenshare::SHARE_MONITOR || !session->m_client)
            return;

        const auto answered = g_answered.find(session);
        if (answered == g_answered.end())
            return;

        const auto monitor = session->monitor();
        if (!monitor || g_commits[monitor.get()] <= answered->second)
            return;

        pid_t pid = 0;
        uid_t uid = 0;
        gid_t gid = 0;
        wl_client_get_credentials(session->m_client, &pid, &uid, &gid);
        if (!isQuickshell(pid))
            return;

        // Answered by the frame that is scheduled; the next request is then armed after it.
        answered->second = g_commits[monitor.get()];
        monitor->scheduleFrame(Aquamarine::IOutput::AQ_SCHEDULE_NEEDS_FRAME);
        g_pHyprRenderer->damageMonitor(monitor);
    }

    Screenshare::eScreenshareError hkShare(void* self, SP<IHLBuffer> buffer, const CRegion& damage, Screenshare::FScreenshareCallback callback) {
        const auto result = reinterpret_cast<ShareFn>(g_hookShare->m_original)(self, buffer, damage, std::move(callback));
        if (result == Screenshare::ERROR_NONE) {
            try {
                rescueLateRequest(static_cast<Screenshare::CScreenshareFrame*>(self));
            } catch (const std::exception&) {
                // The request itself went through; only the extra frame is lost.
            }
        }
        return result;
    }

    // Finds an exported Hyprland function by its mangled-name fragment and hooks it.
    CFunctionHook* hookFunction(const std::string& name, const std::string& signatureFragment, void* replacement) {
        for (auto& match : HyprlandAPI::findFunctionsByName(PHANDLE, name)) {
            if (match.signature.find(signatureFragment) == std::string::npos)
                continue;
            auto* hook = HyprlandAPI::createFunctionHook(PHANDLE, match.address, replacement);
            return (hook && hook->hook()) ? hook : nullptr;
        }
        return nullptr;
    }

    void fail(const std::string& why) {
        HyprlandAPI::addNotification(PHANDLE, "[pane] not loaded: " + why, CHyprColor{1.0, 0.2, 0.2, 1.0}, 8000);
        throw std::runtime_error("[pane] " + why);
    }
}

APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    PHANDLE = handle;

    if (std::string(__hyprland_api_get_hash()) != std::string(__hyprland_api_get_client_hash()))
        fail("built for a different Hyprland version (rebuild the plugin)");

    g_hook = hookFunction("renderMonitor", "CScreenshareFrame13renderMonitorERN6Render14CRenderContextE", reinterpret_cast<void*>(&hkRenderMonitor));
    if (!g_hook)
        fail("could not hook Screenshare::CScreenshareFrame::renderMonitor (Hyprland changed)");

    // The late-request rescue is an extra: without it the captures are still clean.
    g_hookCommit = hookFunction("onOutputCommit", "CScreenshareManager14onOutputCommit", reinterpret_cast<void*>(&hkOnOutputCommit));
    g_hookShare  = hookFunction("share", "CScreenshareFrame5share", reinterpret_cast<void*>(&hkShare));
    if (!g_hookCommit || !g_hookShare) {
        if (g_hookCommit)
            HyprlandAPI::removeFunctionHook(PHANDLE, g_hookCommit);
        if (g_hookShare)
            HyprlandAPI::removeFunctionHook(PHANDLE, g_hookShare);
        g_hookCommit = nullptr;
        g_hookShare  = nullptr;
        HyprlandAPI::addNotification(PHANDLE, "[pane] late-request rescue not active (Hyprland changed); captures are still clean", CHyprColor{1.0, 0.5, 0.1, 1.0}, 6000);
    }

    g_marker = markerPath();
    if (!g_marker.empty()) {
        std::ofstream marker(g_marker);
        marker << getpid() << "\n";
    }

    return {"pane", "Clean captures for Quickshell's glass", "nix-config", "0.1"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    if (g_hookShare)
        HyprlandAPI::removeFunctionHook(PHANDLE, g_hookShare);
    if (g_hookCommit)
        HyprlandAPI::removeFunctionHook(PHANDLE, g_hookCommit);
    if (g_hook)
        HyprlandAPI::removeFunctionHook(PHANDLE, g_hook);
    if (!g_marker.empty())
        std::remove(g_marker.c_str());
}
