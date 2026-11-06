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

    // Three backgrounds take turns. An update is built into one that is not on screen, and is
    // shown by the very frame that builds it: Qt renders what a texture needs before the item
    // that samples it, so no frame is spent on showing it afterwards. readIdx is the one on
    // screen, prevIdx the one shown before it: what is kept when a capture is rejected.
    property int readIdx: 0
    property int prevIdx: 1
    // The scene graph synchronisation count when the last update was scheduled: that update
    // has not been synchronised, and so not rendered, while the count has not gone past it.
    property int scheduledAt: -1
    readonly property Item last: bundleAt(prevIdx).bg
    property int flips: 0
    // Off: captures are received and thrown away (see GlassCapture.publishing).
    property bool processing: true
    // Updates of the pipeline: scheduled, and folded into the one before it (captures that arrived
    // before that one was rendered).
    property int updatesScheduled: 0
    property int updatesDeferred: 0
    // What the GPU counted (see verdict.frag), as of the last read.
    property var validation: ({})
    property bool grabbing: false

    function bundleAt(i) {
        return i === 0 ? bundle0 : (i === 1 ? bundle1 : bundle2);
    }

    // The surface's own history. Every time the glass is updated (flip) the surface changes, and
    // that version is kept in the next slot of a ring (r0..r7) and tagged by one pixel
    // (GlassTag.qml, colour `tagColor`); unmix.frag finds the version of a capture from the tag.
    // So captures may overlap the changes of the glass, and no capture has to be held back.
    // (Rotated into the unmix: see `own` below.)
    readonly property int ringSize: 8
    property int version: 0
    // Bit i: slot i holds a version that was presented.
    property int ringMask: 0
    // Red channel of the tag: one value per instance (bar 30, launcher 34, clipboard 38), so that
    // one instance's tag is never taken for a version of another's.
    property int tagRed: 30
    // Red of the tag that means "my surface is not in this frame", or 0. A popup sets it to the
    // bar's (30): while the popup is closed or still opening that is what shows at the tag's
    // place, and such a capture is the background as it is (see unmix.frag).
    property int absentTagRed: 0
    readonly property color tagColor: Qt.rgba(tagRed / 255, 30 / 255, (46 + 4 * (version % 8)) / 255, 1)
    function ringAt(i) {
        return [r0, r1, r2, r3, r4, r5, r6, r7][i];
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

    // A capture arrived: unmix and blur it into a bundle that is not on screen, and show that
    // bundle (the frame that renders it draws the glass with it).
    function process() {
        if (cap.syncCount() <= scheduledAt) {
            // The update before this one has not been synchronised yet, so it is rendered
            // with the newest capture anyway (that is the one the texture holds then): nothing
            // to schedule, and one update per frame at most (one version of the surface per
            // frame, see `version`).
            updatesDeferred++;
            return;
        }
        // Not the one on screen, which becomes `prev`; of the other two, the one that is not prev.
        let target = (readIdx + 1) % 3;
        if (target === prevIdx)
            target = (readIdx + 2) % 3;
        draftSource.scheduleUpdate();
        flagSource.scheduleUpdate();
        if (diagnostics && !accScheduled) {
            // (Only while the counters are being read: they are of no other use.)
            // One counting pass per round: the one that is not holding the counters reads them.
            accTarget = 1 - accRead;
            (accTarget === 0 ? accSourceA : accSourceB).scheduleUpdate();
            accAfter = cap.syncCount();
            accScheduled = true;
        }
        bundleAt(target).update();
        updatesScheduled++;
        prevIdx = readIdx;
        readIdx = target;
        ready = true;
        flips++;
        // The surface changes in the next synchronised frame, which also draws the new glass:
        // keep that version, tagged.
        bumpVersion();
    }

    // Start a new version of the surface: it is kept (and tagged) as the next synchronised frame
    // renders it. Called for every update, and by a popup that makes its content visible without
    // an update (GlassPopup), so that the version its tag shows holds that content.
    function bumpVersion() {
        version++;
        const slot = version % ringSize;
        ringMask |= 1 << slot;
        ringAt(slot).scheduleUpdate();
        // What the scene graph synchronises from now on includes this update.
        scheduledAt = cap.syncCount();
    }

    // A frame was presented.
    function handleSwapped(syncSerial) {
        if (accScheduled && syncSerial > accAfter) {
            accRead = accTarget;
            accScheduled = false;
        }
    }

    // What we presented: one version of the surface's content per slot, as the scene graph
    // rendered it (see `version`). Not live: a slot is rendered when the glass is flipped.
    ShaderEffectSource {
        id: r0
        sourceItem: root.composite
        live: false
        visible: false
        textureSize: root.sizePx
    }

    ShaderEffectSource {
        id: r1
        sourceItem: root.composite
        live: false
        visible: false
        textureSize: root.sizePx
    }

    ShaderEffectSource {
        id: r2
        sourceItem: root.composite
        live: false
        visible: false
        textureSize: root.sizePx
    }

    ShaderEffectSource {
        id: r3
        sourceItem: root.composite
        live: false
        visible: false
        textureSize: root.sizePx
    }

    ShaderEffectSource {
        id: r4
        sourceItem: root.composite
        live: false
        visible: false
        textureSize: root.sizePx
    }

    ShaderEffectSource {
        id: r5
        sourceItem: root.composite
        live: false
        visible: false
        textureSize: root.sizePx
    }

    ShaderEffectSource {
        id: r6
        sourceItem: root.composite
        live: false
        visible: false
        textureSize: root.sizePx
    }

    ShaderEffectSource {
        id: r7
        sourceItem: root.composite
        live: false
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
        // The slot that is being rendered in this very frame (the version being presented) is
        // not read: a capture cannot hold a frame that has not been presented, and reading it
        // would make the unmix wait for a snapshot that waits for the unmix.
        property variant own0: root.version % 8 === 0 ? r1 : r0
        property variant own1: root.version % 8 === 1 ? r2 : r1
        property variant own2: root.version % 8 === 2 ? r3 : r2
        property variant own3: root.version % 8 === 3 ? r4 : r3
        property variant own4: root.version % 8 === 4 ? r5 : r4
        property variant own5: root.version % 8 === 5 ? r6 : r5
        property variant own6: root.version % 8 === 6 ? r7 : r6
        property variant own7: root.version % 8 === 7 ? r0 : r7
        property vector2d texPx: Qt.vector2d(root.texPx.width, root.texPx.height)
        property real tagMask: root.ringMask
        property real tagRed: root.tagRed
        property real absentRed: root.absentTagRed
        property variant previous: root.last

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
        property variant own0: root.version % 8 === 0 ? r1 : r0
        property variant own1: root.version % 8 === 1 ? r2 : r1
        property variant own2: root.version % 8 === 2 ? r3 : r2
        property variant own3: root.version % 8 === 3 ? r4 : r3
        property variant own4: root.version % 8 === 4 ? r5 : r4
        property variant own5: root.version % 8 === 5 ? r6 : r5
        property variant own6: root.version % 8 === 6 ? r7 : r6
        property variant own7: root.version % 8 === 7 ? r0 : r7
        property vector2d texPx: Qt.vector2d(root.texPx.width, root.texPx.height)
        property real tagMask: root.ringMask
        property real tagRed: root.tagRed
        property real absentRed: root.absentTagRed
        property variant previous: root.last

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
        // What a bundle keeps when a capture is rejected: the background that was on screen
        // before it (`last`). Never its own output (a cycle in the texture graph): the previous
        // one is not rebuilt, so what it keeps then does not matter.
        kept: root.prevIdx === 0 ? draftSource : root.last
        sizePx: root.texPx
        sigma: root.blurRadius * root.texPx.width / Math.max(1, root.width)
    }

    GlassBundle {
        id: bundle1
        draft: draftSource
        flag: flagSource
        kept: root.prevIdx === 1 ? draftSource : root.last
        sizePx: root.texPx
        sigma: root.blurRadius * root.texPx.width / Math.max(1, root.width)
    }

    GlassBundle {
        id: bundle2
        draft: draftSource
        flag: flagSource
        kept: root.prevIdx === 2 ? draftSource : root.last
        sizePx: root.texPx
        sigma: root.blurRadius * root.texPx.width / Math.max(1, root.width)
    }

    // Keep-alive consumer. Qt appears to render a hidden, non-live ShaderEffectSource only when
    // something visible samples it, and the glass samples only the shown bundle: so an update of
    // a bundle that is not shown waited until it was shown, and was then rebuilt while shown (its
    // `kept` was itself). One tiny item outside the window that samples every texture of the
    // pipeline that is scheduled by hand (the three bundles and the ring) makes Qt render them
    // when scheduled. What it draws is never seen. (One item and one draw call for all of them:
    // fourteen separate ones were a measurable part of the cost.)
    ShaderEffect {
        x: -64
        width: 1 / root.ratio
        height: 1 / root.ratio
        blending: false
        property variant k0: bundle0.bg
        property variant k1: bundle0.frosted
        property variant k2: bundle1.bg
        property variant k3: bundle1.frosted
        property variant k4: bundle2.bg
        property variant k5: bundle2.frosted
        property variant k6: r0
        property variant k7: r1
        property variant k8: r2
        property variant k9: r3
        property variant k10: r4
        property variant k11: r5
        property variant k12: r6
        property variant k13: r7
        fragmentShader: Qt.resolvedUrl("shaders/keepalive.frag.qsb")
    }

    Component.onCompleted: {
        // Version 0 is the surface as it starts.
        ringMask = 1;
        r0.scheduleUpdate();
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
                    version: root.version,
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
