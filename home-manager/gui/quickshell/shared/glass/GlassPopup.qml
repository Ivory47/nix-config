import QtQuick
import Quickshell
import Quickshell.Wayland

// A full-screen overlay window for a popup panel with live glass (the app launcher, the
// clipboard history): everything that is the same for them lives here.
//
// Put the popup's items inside it (they become the children of `content`, the surface the glass
// is computed for) and give the GlassListPanel `popup: <this window's id>`. Set
// WlrLayershell.namespace on the instance. Open and close it with `shown`, never with `visible`.
//
//  - The window stays mapped. Quickshell destroys and re-creates the Qt window when `visible`
//    goes false and true again, and the glass items crash that re-creation (segfault in
//    QQuickWindow::maybeUpdate). So only `shown` changes: no input, no focus and no content
//    while hidden, and the glass capture is off.
//  - It covers the whole output, over the bar: the glass needs the surface at the output's top
//    left (the tag pixel), which an exclusive zone would move.
//  - It takes the keyboard exclusively while shown. ("focusable" only asks for it on demand,
//    which the compositor often does not grant to a window that was already mapped.)
//  - The glass is drawn from the background it saved the last time the popup was open, and it
//    subtracts that old picture of what leaks through it: when the screen behind has changed,
//    the old content shows up inverted until the first new capture. So until the pipeline has
//    taken fresh captures (a few frames) the glass does not subtract anything (cancelAmount,
//    GlassPanel.cancelLeak); then it is ramped in, so that no single frame can jump. For about
//    150 ms after opening a faint trace of the real, sharp background shows through.
PanelWindow {
    id: root

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"

    // Open / closed.
    property bool shown: false
    // The list row under the mouse, if any: set by the rows, highlighted by the GlassListPanel.
    property Item hoveredItem: null
    // The item that gets the keyboard when the popup is shown (the search field).
    property Item focusItem: null
    // Blur strength: gaussian sigma in logical pixels.
    property real blurRadius: 14
    // How long after opening to wait for fresh captures at most, ms.
    property int revealTimeout: 400
    // Ramp of the leak cancelling, ms. Shorter than this (80) flashed, longer (250) left the sharp
    // background showing for too long.
    property int rampDuration: 150

    // 0 while the recovered background may be out of date, then up to 1.
    property real cancelAmount: 0
    readonly property alias backdrop: glassBackdrop
    // The root of everything that is drawn.
    readonly property alias content: surface

    // Emitted after `shown` changed (Quickshell windows have a `closed` signal of their own).
    signal popupOpened()
    signal popupClosed()

    default property alias items: surface.data

    mask: shown ? null : emptyMask

    Region {
        id: emptyMask
    }

    property bool revealed: false
    property int flipsAtOpen: 0

    function reveal() {
        revealTimer.stop()
        revealed = true
        cancelRamp.restart()
    }

    NumberAnimation {
        id: cancelRamp
        target: root
        property: "cancelAmount"
        from: 0
        to: 1
        duration: root.rampDuration
    }

    Timer {
        // In case no capture comes (nothing changed behind, so the old picture is right).
        id: revealTimer
        interval: root.revealTimeout
        onTriggered: root.reveal()
    }

    Connections {
        target: glassBackdrop

        function onFlipsChanged() {
            // Two updates: the first capture may predate the surface (no tag in it) and be refused.
            if (root.shown && !root.revealed && glassBackdrop.flips >= root.flipsAtOpen + 2)
                root.reveal()
        }
    }

    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onShownChanged: {
        revealTimer.stop()
        cancelRamp.stop()
        cancelAmount = 0
        revealed = false

        if (shown) {
            flipsAtOpen = glassBackdrop.flips
            revealTimer.start()
            if (focusItem)
                focusItem.forceActiveFocus()
            // Again once the compositor has handed over the keyboard.
            focusTimer.restart()
            popupOpened()
        } else {
            popupClosed()
        }
    }

    Timer {
        id: focusTimer
        interval: 60
        onTriggered: if (root.shown && root.focusItem) root.focusItem.forceActiveFocus()
    }

    Item {
        id: surface
        anchors.fill: parent
        visible: root.shown

        // One opaque pixel at the top left: says which version of the surface a capture holds.
        GlassTag {
            backdrop: glassBackdrop
        }
    }

    // Captures and unmixes what is behind this surface. Only while shown.
    GlassBackdrop {
        id: glassBackdrop
        composite: surface
        blurRadius: root.blurRadius
        ipcTarget: "glass"
        active: root.shown
    }
}
