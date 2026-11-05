import QtQuick
import Quickshell
import Quickshell.Io
import Glass.Native

// The live backdrop of a layer-shell surface: what is really behind it, kept up to date.
//
// The pipeline is Pleamar's:
//   1. GlassCapture asks the compositor for only this surface's region (wlr-screencopy):
//      always one request on its way, answered when something behind changes
//      (copy_with_damage), at most once per refresh period of the monitor.
//   2. The capture contains our own surface. `own`, a texture of exactly what we presented,
//      is subtracted and the rest divided by what our surface lets through: the real
//      background (unmix.frag). A second pass flags pixels where capture and own cannot belong
//      to the same frame; if more than 1% are wrong the capture is dropped (settle.frag).
//   3. The background is blurred on the GPU (blur.frag).
//   4. GlassPanel draws the glass from `sharp` and `frosted`.
//
// Place one GlassBackdrop per surface, outside of `composite` (the item whose rendering is the
// content of the surface), and give GlassPanels inside `composite` its `sharp` and `frosted`.
// The same backdrop can feed any number of panels with different looks.
Item {
    id: root

    // The root item of the surface's content: everything the compositor receives, glass included.
    required property Item composite
    // Top left of the surface, in logical pixels of the output.
    property point origin: Qt.point(0, 0)
    // Blur strength: gaussian sigma in logical pixels.
    property real blurRadius: 14
    // Minimum time between captures in ms. 0 = one refresh period of the monitor.
    property int minInterval: 0
    property bool active: true
    // Off: no capture, nothing kept up to date (for comparing against the bar without glass).
    property bool glassEnabled: true
    // Log what the pipeline does (twice a second).
    property bool debug: false
    // Name of an IPC target (`qs ipc call <target> ...`) to switch parts of the pipeline on and
    // off and read counters while it runs, for measuring. Empty: none.
    property string ipcTarget: ""
    // Read the validation counters back from the GPU twice a second (asynchronously; one small
    // read, and a frame for it). Off by default, and switched on through IPC when measuring.
    property bool diagnostics: false
    // For tests: treat every capture as the wrong frame, as a transient failure would. The glass
    // must then keep the last valid background.
    property bool forceReject: false

    // What GlassPanel reads.
    readonly property Item sharp: bundleAt(readIdx).bg
    readonly property Item frosted: bundleAt(readIdx).frosted
    // Size of the surface in real pixels, as we render it.
    readonly property size sizePx: Qt.size(
        Math.max(1, Math.round(width * ratio)),
        Math.max(1, Math.round(height * ratio)))
    readonly property real ratio: cap.pixelRatio
    // The compositor may take the surface at another scale than the one we render at (it
    // resamples). Unmixing is done on the capture's own grid, and `own` is read by uv, as the
    // compositor read the surface.
    readonly property size texPx: cap.captureSize.width > 0 ? cap.captureSize : sizePx
    // True once a background has been settled; before that panels draw a plain tint.
    property bool ready: false
    readonly property alias capture: cap

    width: composite.width
    height: composite.height

    // Three backgrounds take turns. One is shown (readIdx); updates go to one that is not,
    // and what was updated is shown once the frame that rendered it has been presented.
    // So nothing that is being rebuilt is ever read by what is drawn in the same frame, and an
    // update does not have to wait for the one before it.
    property int readIdx: 0
    property var pending: []
    property bool again: false
    property int flips: 0
    // Off: captures are received and thrown away (see GlassCapture.publishing).
    property bool processing: true
    // Updates of the pipeline: scheduled, and put off because no background was free to take them.
    property int updatesScheduled: 0
    property int updatesDeferred: 0
    // What the GPU counted (see verdict.frag), as of the last read.
    property var validation: ({})
    property bool grabbing: false

    function bundleAt(i) {
        return i === 0 ? bundle0 : (i === 1 ? bundle1 : bundle2);
    }

    GlassCapture {
        id: cap
        active: root.active && root.glassEnabled
        region: Qt.rect(root.origin.x, root.origin.y, root.width, root.height)
        minInterval: root.minInterval
        onCaptured: root.process()
        publishing: root.processing
        onSwapped: syncSerial => root.handleSwapped(syncSerial)
    }

    // A capture arrived: unmix and blur it into a bundle that is not on screen.
    function process() {
        let target = -1;
        for (let i = 0; i < 3; i++) {
            if (i !== readIdx && !pending.some(p => p.idx === i)) {
                target = i;
                break;
            }
        }
        if (target < 0) {
            // Both free ones are waiting to be shown: do this capture when one is free.
            again = true;
            updatesDeferred++;
            return;
        }
        draftSource.scheduleUpdate();
        flagSource.scheduleUpdate();
        if (!accScheduled) {
            // One counting pass per round: the one that is not holding the counters reads them.
            accTarget = 1 - accRead;
            (accTarget === 0 ? accSourceA : accSourceB).scheduleUpdate();
            accAfter = cap.syncCount();
            accScheduled = true;
        }
        bundleAt(target).update();
        updatesScheduled++;
        // What the scene graph synchronises from now on includes this update.
        pending.push({ idx: target, after: cap.syncCount() });
    }

    // A frame was presented. If it was synchronised after an update was scheduled, that
    // update was rendered by it: show the newest of those.
    function handleSwapped(syncSerial) {
        let best = -1;
        for (let i = 0; i < pending.length; i++) {
            if (syncSerial > pending[i].after)
                best = i;
        }
        if (best < 0)
            return;
        if (accScheduled && syncSerial > accAfter) {
            accRead = accTarget;
            accScheduled = false;
        }
        readIdx = pending[best].idx;
        pending = pending.slice(best + 1);
        ready = true;
        flips++;
        if (again) {
            again = false;
            process();
        }
    }

    // What we presented: the surface's content as the scene graph renders it.
    ShaderEffectSource {
        id: ownSource
        sourceItem: root.composite
        live: root.glassEnabled
        visible: false
        textureSize: root.sizePx
    }

    ShaderEffect {
        id: draftFx
        width: root.texPx.width
        height: root.texPx.height
        visible: false
        blending: false

        property real mode: 0
        property real coverOpacity: 1
        property vector2d capOrigin: Qt.vector2d(cap.cropUv.x, cap.cropUv.y)
        property vector2d capScale: Qt.vector2d(cap.cropUv.width, cap.cropUv.height)
        property real forceBad: root.forceReject ? 1 : 0
        property variant capture: cap
        property variant own: ownSource
        property variant previous: root.sharp

        fragmentShader: Qt.resolvedUrl("shaders/unmix.frag.qsb")
    }

    ShaderEffectSource {
        id: draftSource
        sourceItem: draftFx
        live: false
        visible: false
        textureSize: root.texPx
    }

    ShaderEffect {
        id: flagFx
        width: root.texPx.width
        height: root.texPx.height
        visible: false
        blending: false

        property real mode: 1
        property real coverOpacity: 1
        property vector2d capOrigin: Qt.vector2d(cap.cropUv.x, cap.cropUv.y)
        property vector2d capScale: Qt.vector2d(cap.cropUv.width, cap.cropUv.height)
        property real forceBad: root.forceReject ? 1 : 0
        property variant capture: cap
        property variant own: ownSource
        property variant previous: root.sharp

        fragmentShader: Qt.resolvedUrl("shaders/unmix.frag.qsb")
    }

    // Float, with mip levels: the top level is the fraction of wrong pixels.
    ShaderEffectSource {
        id: flagSource
        sourceItem: flagFx
        live: false
        visible: false
        mipmap: true
        format: ShaderEffectSource.RGBA16F
        textureSize: root.texPx
    }

    // What settle.frag decides, counted on the GPU (verdict.frag): a 3x1 float texture, rewritten
    // by one pass per update of the pipeline from its previous contents. Two take turns (A reads
    // B and is written, then B reads A), because a texture cannot be read and written in the same
    // pass (Qt's `recursive` gave garbage here). At most one pass per frame; nothing is read back
    // per capture.
    ShaderEffect {
        id: accFxA
        width: 3
        height: 1
        visible: false
        blending: false

        property real areaPx: root.texPx.width * root.texPx.height
        property variant flag: flagSource
        property variant acc: accSourceB

        fragmentShader: Qt.resolvedUrl("shaders/verdict.frag.qsb")
    }

    ShaderEffectSource {
        id: accSourceA
        sourceItem: accFxA
        live: false
        smooth: false
        visible: false
        format: ShaderEffectSource.RGBA32F
        textureSize: Qt.size(3, 1)
    }

    ShaderEffect {
        id: accFxB
        width: 3
        height: 1
        visible: false
        blending: false

        property real areaPx: root.texPx.width * root.texPx.height
        property variant flag: flagSource
        property variant acc: accSourceA

        fragmentShader: Qt.resolvedUrl("shaders/verdict.frag.qsb")
    }

    ShaderEffectSource {
        id: accSourceB
        sourceItem: accFxB
        live: false
        smooth: false
        visible: false
        format: ShaderEffectSource.RGBA32F
        textureSize: Qt.size(3, 1)
    }

    // Which one holds the latest counters, and the update that is on its way.
    property int accRead: 0
    property int accTarget: 0
    property int accAfter: 0
    property bool accScheduled: false

    // The counters as bytes, outside the window, for the occasional grabToImage().
    ShaderEffect {
        id: readoutFx
        x: -64
        y: 0
        // Exactly 12 x 1 real pixels, so that the grab is not resampled (which would mix the bytes
        // of neighbouring numbers).
        width: 12 / root.ratio
        height: 1 / root.ratio
        visible: root.diagnostics && root.glassEnabled
        blending: false

        property variant acc: root.accRead === 0 ? accSourceA : accSourceB

        fragmentShader: Qt.resolvedUrl("shaders/readout.frag.qsb")
    }

    Timer {
        interval: 500
        running: root.diagnostics && root.glassEnabled
        repeat: true
        onTriggered: {
            if (root.grabbing)
                return;
            root.grabbing = true;
            readoutFx.grabToImage(result => {
                root.grabbing = false;
                root.decode(result.image);
            }, Qt.size(12, 1));
        }
    }

    function decode(image) {
        const scale = [1, 1, 1, 1, 1000, 1000, 10000, 10000, 1, 1, 1000, 10000];
        const v = [];
        for (let i = 0; i < 12; i++) {
            const c = cap.readPixel(image, i, 0);
            const n = Math.round(c.r * 255) + Math.round(c.g * 255) * 256 + Math.round(c.b * 255) * 65536;
            v.push(n / scale[i]);
        }
        const processed = v[0] + v[1] + v[2];
        const avg = x => processed > 0 ? 100 * x / processed : 0;
        validation = {
            processed: processed,
            accepted: v[0],
            rejectedWrongFrame: v[1],
            rejectedUnusable: v[2],
            validBackdropSeen: v[3] > 0.5,
            unknownPctAvg: avg(v[4]),
            wrongPctAvg: avg(v[5]),
            unknownPctLast: 100 * v[6],
            wrongPctLast: 100 * v[7],
            impossiblePctAvg: avg(v[10]),
            impossiblePctLast: 100 * v[11],
            // The glass was on its plain tint, there being no valid background yet.
            greyFallbackNoBackdrop: v[8],
            // A capture was rejected and the last valid background kept instead.
            heldLastGood: v[9]
        };
    }

    GlassBundle {
        id: bundle0
        draft: draftSource
        flag: flagSource
        kept: root.sharp
        sizePx: root.texPx
        sigma: root.blurRadius * root.texPx.width / Math.max(1, root.width)
    }

    GlassBundle {
        id: bundle1
        draft: draftSource
        flag: flagSource
        kept: root.sharp
        sizePx: root.texPx
        sigma: root.blurRadius * root.texPx.width / Math.max(1, root.width)
    }

    GlassBundle {
        id: bundle2
        draft: draftSource
        flag: flagSource
        kept: root.sharp
        sizePx: root.texPx
        sigma: root.blurRadius * root.texPx.width / Math.max(1, root.width)
    }

    IpcHandler {
        enabled: root.ipcTarget !== ""
        target: root.ipcTarget

        // Captures on / off (off: nothing is requested at all).
        function setCapture(on: bool): void { root.active = on; }
        // Off: the glass is not drawn and nothing of the pipeline runs.
        function setGlass(on: bool): void { root.glassEnabled = on; }
        // Off: captures are received and thrown away; nothing is shown or rendered.
        function setProcessing(on: bool): void { root.processing = on; }
        function setDepth(n: int): void { cap.depth = n; }
        function setDmabuf(on: bool): void { cap.allowDmabuf = on; }
        // On: capture the whole output and crop here. Off: ask the compositor for the region.
        function setWholeOutput(on: bool): void { cap.wholeOutput = on; }
        function setInterval(ms: int): void { cap.minInterval = ms; }
        // For tests: at most this many dmabufs in the pool (0 = default), to force exhaustion.
        function setPoolLimit(n: int): void { cap.poolLimit = n; }
        // For tests: every capture is treated as the wrong frame.
        function setForceReject(on: bool): void { root.forceReject = on; }
        // Read the GPU validation counters back twice a second.
        function setDiagnostics(on: bool): void { root.diagnostics = on; }
        // Cumulative counters; take two readings and subtract.
        function stats(): string {
            return JSON.stringify({
                capture: cap.diagnostics(),
                validation: root.validation,
                pipeline: {
                    flips: root.flips,
                    updatesScheduled: root.updatesScheduled,
                    updatesDeferred: root.updatesDeferred,
                    ready: root.ready,
                    forceReject: root.forceReject,
                    diagnostics: root.diagnostics
                },
                settings: {
                    glass: root.glassEnabled,
                    active: root.active,
                    processing: root.processing,
                    depth: cap.depth,
                    wholeOutput: cap.wholeOutput,
                    allowDmabuf: cap.allowDmabuf,
                    poolLimit: cap.poolLimit,
                    interval: cap.minInterval,
                    status: cap.status
                },
                size: {
                    capture: cap.captureSize.width + "x" + cap.captureSize.height,
                    region: cap.region.x + "," + cap.region.y + " " + cap.region.width + "x" + cap.region.height
                }
            });
        }
    }

    property int lastReceived: 0
    property int lastRequests: 0
    property int lastCompletions: 0
    property int lastDuplicates: 0
    property int lastFlips: 0

    Timer {
        interval: 500
        running: root.debug
        repeat: true
        onTriggered: {
            const d = cap.diagnostics();
            const v = root.validation;
            console.log(
                "glass: ready", root.ready,
                "| requests/s", (d.requests - root.lastRequests) * 2,
                "completions/s", (d.completions - root.lastCompletions) * 2,
                "published/s", (d.published - root.lastReceived) * 2,
                "duplicates/s", (d.duplicates - root.lastDuplicates) * 2,
                "damage events", d.damageEvents, "(full", d.damageFull + ")",
                "| pool", d.poolSize, "free", d.poolFree, "retiring", d.poolRetiring,
                "exhausted", d.poolExhausted, "allocFail", d.allocFailures, "importFail", d.importFailures,
                "broken", d.dmabufBroken,
                "| validation accepted", v.accepted, "rejected", (v.rejectedWrongFrame + v.rejectedUnusable),
                "unknown%", v.unknownPctLast !== undefined ? v.unknownPctLast.toFixed(1) : "-",
                "| latency", cap.latency.toFixed(1) + "ms",
                "status", cap.status);
            root.lastRequests = d.requests;
            root.lastCompletions = d.completions;
            root.lastDuplicates = d.duplicates;
            root.lastReceived = cap.serial;
            root.lastFlips = root.flips;
        }
    }
}
