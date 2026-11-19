import QtQuick
import Quickshell

// The base of a NORMAL WINDOW with compositor glass (the settings window, the wallpaper picker): a
// FloatingWindow that is open while `shown` is true (the window only exists then; closing it from the
// compositor, Super+C, sets `shown` false), has a transparent background for the glass to show through,
// and gets the keyboard on `focusSoon()`. Put a GlassWindowPanel first in its content; guide:
// GLASS-WINDOWS.md. (The popups on layer surfaces are GlassPopup.)
FloatingWindow {
    id: win

    color: "transparent"

    property bool shown: false
    visible: shown
    onClosed: shown = false

    // The row or card under the mouse, if any (set by the rows, highlighted by the glass).
    property Item hoveredItem: null
    // The item that gets the keyboard when the window opens.
    property Item focusItem: null

    function closeWindow() {
        shown = false
    }

    // Focus it now and again shortly after: the compositor may give a new window the keyboard a
    // moment after it is mapped.
    function focusSoon() {
        if (focusItem)
            focusItem.forceActiveFocus()
        focusTimer.restart()
    }

    Timer {
        id: focusTimer
        interval: 80
        onTriggered: if (win.shown && win.focusItem) win.focusItem.forceActiveFocus()
    }
}
