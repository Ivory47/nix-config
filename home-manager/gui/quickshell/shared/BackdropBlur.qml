import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

// Reusable backdrop blur, independent of the compositor's blur. Strength: Theme.backdropBlur.
//
// A layer-shell client cannot read what is behind it, so this takes a screencopy snapshot of
// the output and blurs only the slice that lies behind this item. Place it underneath your
// content (e.g. first child of the window's content) and pass the window's screen.
//
// The snapshot must not contain the window itself (otherwise the blur would just blur its own
// previous frame). While `capturing` is true the host must hide its own content (bind e.g.
// `visible: !blur.capturing`); this item hides its blur too. The capture stops afterwards, so
// there is no continuous desktop capture. It runs on load and whenever refresh() is called.
//
// Assumes the surface starts at the screen's top-left corner (true for a top bar anchored
// left/right/top). Use sourceX/sourceY for other placements.
Item {
    id: root

    required property var screen
    property real sourceX: 0
    property real sourceY: 0

    // Delays in ms: let the compositor present the emptied window, then capture a few frames.
    property int settleDelay: 150
    property int captureTime: 250

    property bool capturing: false

    clip: true

    function refresh() {
        if (capturing)
            return;
        capturing = true;
        settleTimer.start();
    }

    Component.onCompleted: refresh()

    Timer {
        id: settleTimer
        interval: root.settleDelay
        onTriggered: {
            capture.live = true;
            finishTimer.start();
        }
    }

    Timer {
        id: finishTimer
        interval: root.captureTime
        onTriggered: {
            console.log("BackdropBlur: captured, hasContent =", capture.hasContent, "sourceSize =", capture.sourceSize);
            capture.live = false;
            root.capturing = false;
        }
    }

    ScreencopyView {
        id: capture
        captureSource: root.screen
        live: false
        visible: false
        width: root.screen.width
        height: root.screen.height
    }

    ShaderEffectSource {
        id: slice
        anchors.fill: parent
        sourceItem: capture
        sourceRect: Qt.rect(root.sourceX, root.sourceY, root.width, root.height)
        live: true
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        visible: !root.capturing
        source: slice
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blur: Theme.backdropBlur
    }
}
