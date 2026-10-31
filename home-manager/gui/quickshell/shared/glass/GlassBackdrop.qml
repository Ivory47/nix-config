import QtQuick
import Glass.Native

// The live backdrop of a layer-shell surface: what is really behind it, kept up to date.
//
// The pipeline is Pleamar's:
//   1. GlassCapture asks the compositor for only this surface's region (wlr-screencopy),
//      after every presented frame, and while idle for the next change (copy_with_damage).
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
    readonly property Item sharp: readIdx === 0 ? bundle0.bg : bundle1.bg
    readonly property Item frosted: readIdx === 0 ? bundle0.frosted : bundle1.frosted
    readonly property size sizePx: Qt.size(
        Math.max(1, Math.round(width * ratio)),
        Math.max(1, Math.round(height * ratio)))
    readonly property real ratio: cap.pixelRatio
    // True once a background has been settled; before that panels draw a plain tint.
    property bool ready: false
    readonly property alias capture: cap

    width: composite.width
    height: composite.height

    property int readIdx: 0
    property int pendingIdx: 0
    property bool flipPending: false
    property int flipAfter: 0

    GlassCapture {
        id: cap
        active: root.active
        region: Qt.rect(root.origin.x, root.origin.y, root.width, root.height)
        minInterval: root.minInterval
        onCaptured: root.process()
        onSwapped: syncSerial => root.handleSwapped(syncSerial)
    }

    // A capture arrived: unmix and blur it into the bundle that is not on screen.
    function process() {
        const target = 1 - readIdx;
        draftSource.scheduleUpdate();
        flagSource.scheduleUpdate();
        (target === 0 ? bundle0 : bundle1).update();
        pendingIdx = target;
        // What the scene graph synchronises from now on includes this update.
        flipAfter = cap.syncCount();
        flipPending = true;
    }

    // The frame that did the work has been presented: show its result. Until then nothing that
    // was being rebuilt is read by anything that is drawn.
    function handleSwapped(syncSerial) {
        if (!flipPending || syncSerial <= flipAfter)
            return;
        readIdx = pendingIdx;
        flipPending = false;
        ready = true;
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
        width: root.sizePx.width
        height: root.sizePx.height
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
        textureSize: root.sizePx
    }

    ShaderEffect {
        id: flagFx
        width: root.sizePx.width
        height: root.sizePx.height
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
        textureSize: root.sizePx
    }

    GlassBundle {
        id: bundle0
        draft: draftSource
        flag: flagSource
        kept: bundle1.bg
        sizePx: root.sizePx
        sigma: root.blurRadius * root.ratio
    }

    GlassBundle {
        id: bundle1
        draft: draftSource
        flag: flagSource
        kept: bundle0.bg
        sizePx: root.sizePx
        sigma: root.blurRadius * root.ratio
    }

    Timer {
        interval: 500
        running: root.debug
        repeat: true
        onTriggered: console.log(
            "glass: ready", root.ready,
            "serial", cap.serial,
            "received", cap.received,
            "skipped", cap.skipped,
            "failed", cap.failed,
            "interval", cap.effectiveInterval.toFixed(1) + "ms",
            "ratio", root.ratio,
            "windowDpr", root.Window.window ? root.Window.window.devicePixelRatio : -1,
            "screenDpr", root.Window.window && root.Window.window.screen ? root.Window.window.screen.devicePixelRatio : -1,
            "px", root.sizePx.width + "x" + root.sizePx.height,
            "capture", cap.captureSize.width + "x" + cap.captureSize.height,
            "status", cap.status)
    }
}
