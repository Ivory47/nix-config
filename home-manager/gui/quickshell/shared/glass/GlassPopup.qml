import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.shared

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
//    the old content shows up inverted until the first new capture. So opening is in two steps:
//    `shown` starts the capture with the content still hidden (nothing of ours is in the frame,
//    so the capture is the background as it is: unmix.frag, absentTagRed), and the content is
//    made visible by the first update (`presented`), with the fresh background and the leak
//    cancelled at once. That costs a capture round trip (about two frames) before the popup
//    appears. If no update comes within `presentTimeout` (nothing changed behind, or no bar tag to
//    tell an empty frame by), the content is shown anyway and the old way is used: the glass does
//    not subtract anything (cancelAmount, GlassPanel.cancelLeak) until two fresh updates have
//    arrived, then it is ramped in, so that no single frame can jump (a faint trace of the real,
//    sharp background shows through for about 150 ms).
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
    // How long after `shown` to wait for the first fresh background before showing the content
    // anyway, ms.
    property int presentTimeout: 80
    // How long after the content appeared to wait for fresh captures at most (only when it
    // appeared without one), ms.
    property int revealTimeout: 400
    // Red channel of the tag pixel: every GlassBackdrop has its own, so that the bar's is not
    // taken for this popup's (bar 30, launcher 34, clipboard 38).
    property int tagRed: 34
    // Ramp of the leak cancelling, ms. Shorter than this (80) flashed, longer (250) left the sharp
    // background showing for too long.
    property int rampDuration: 150

    // 0 while the recovered background may be out of date, then up to 1.
    property real cancelAmount: 0
    // The content is on screen. Follows `shown` after the first fresh background (or a timeout)
    // when opening, at once when closing.
    property bool presented: false
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

    // Fallback ramp: the background may be out of date (see the header).
    function reveal() {
        revealTimer.stop()
        revealed = true
        cancelRamp.restart()
    }

    // Make the content visible. `fresh`: a new background was taken just now with nothing of ours
    // in the frame, so nothing is stale and the leak can be cancelled in full at once.
    function present(fresh) {
        if (!shown || presented)
            return
        presentTimer.stop()
        presented = true
        if (fresh) {
            revealed = true
            cancelAmount = 1
        } else {
            // No update came: the content has not been in any version of the surface that was
            // kept, and the tag would name a version without it. Start a new one.
            flipsAtOpen = glassBackdrop.flips
            glassBackdrop.bumpVersion()
            revealTimer.start()
        }
        if (focusItem)
            focusItem.forceActiveFocus()
        focusTimer.restart()
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

    Timer {
        // In case no update comes to open on.
        id: presentTimer
        interval: root.presentTimeout
        onTriggered: root.present(false)
    }

    Connections {
        target: glassBackdrop

        function onFlipsChanged() {
            if (!root.shown)
                return
            // Opening: the first update was made from a frame without the content in it. (This
            // runs inside the update, before the frame that shows it: that frame also keeps the
            // version of the surface that the tag will name, content included.)
            if (!root.presented) {
                root.present(true)
                return
            }
            // Opened by the timeout: two updates, since the first capture may predate the surface
            // (no tag in it) and be refused.
            if (!root.revealed && glassBackdrop.flips >= root.flipsAtOpen + 2)
                root.reveal()
        }
    }

    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onShownChanged: {
        revealTimer.stop()
        presentTimer.stop()
        cancelRamp.stop()
        cancelAmount = 0
        revealed = false
        presented = false

        if (shown) {
            flipsAtOpen = glassBackdrop.flips
            if (glassBackdrop.glassEnabled)
                // The content appears with the first update, or when this runs out.
                presentTimer.start()
            else
                // Glass off (Theme.glass): no capture is coming, nothing to wait for.
                present(true)
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
        visible: root.presented

        // One opaque pixel at the top left: says which version of the surface a capture holds.
        GlassTag {
            backdrop: glassBackdrop
        }
    }

    // Captures and unmixes what is behind this surface. Only while shown (including the moment
    // before the content appears). The bar's tag (red 30) at the tag's place means that the
    // content is not in the frame.
    GlassBackdrop {
        id: glassBackdrop
        composite: surface
        blurRadius: root.blurRadius
        ipcTarget: "glass"
        active: root.shown
        glassEnabled: Theme.glass
        tagRed: root.tagRed
        absentTagRed: 30
    }
}
