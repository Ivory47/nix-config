import QtQuick
import Quickshell
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
    // Log what the pipeline does (twice a second).
    property bool debug: false

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

    function bundleAt(i) {
        return i === 0 ? bundle0 : (i === 1 ? bundle1 : bundle2);
    }

    GlassCapture {
        id: cap
        active: root.active
        region: Qt.rect(root.origin.x, root.origin.y, root.width, root.height)
        minInterval: root.minInterval
        onCaptured: root.process()
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
            return;
        }
        draftSource.scheduleUpdate();
        flagSource.scheduleUpdate();
        bundleAt(target).update();
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
        live: true
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

    property int lastReceived: 0
    property int lastFlips: 0

    Timer {
        interval: 500
        running: root.debug
        repeat: true
        onTriggered: {
            console.log(
                "glass: ready", root.ready,
                "| captures/s", (cap.serial - root.lastReceived) * 2,
                "flips/s", (root.flips - root.lastFlips) * 2,
                "| dmabuf", cap.usingDmabuf,
                "received", cap.received,
                "published", cap.serial,
                "skipped", cap.skipped,
                "failed", cap.failed,
                "| interval", cap.effectiveInterval.toFixed(1) + "ms",
                "latency", cap.latency.toFixed(1) + "ms",
                "setup", cap.setupLatency.toFixed(1) + "ms",
                "cycle", cap.cycle.toFixed(1) + "ms",
                "ratio", root.ratio,
                "px", root.sizePx.width + "x" + root.sizePx.height,
                "capture", cap.captureSize.width + "x" + cap.captureSize.height,
                "status", cap.status);
            root.lastReceived = cap.serial;
            root.lastFlips = root.flips;
        }
    }
}
