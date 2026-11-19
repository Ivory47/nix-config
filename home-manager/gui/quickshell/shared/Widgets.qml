pragma Singleton

import QtQuick
import Quickshell

// "One widget at a time". Each shell runs in its own process, so a widget that opens asks every other
// running Quickshell shell to close, over IPC: the target `widget`, function `closeForOther()`. Nothing is
// registered here: a shell takes part by having that target (GlassPopup has it built in, so every popup
// does; the wallpaper overlay and the bar have their own in their shell.qml). A widget that should ignore
// the rule sets `exclusive: false` on its GlassPopup (the clipboard): its `closeForOther()` does nothing and
// it does not close the others. Normal windows (the settings window, the wallpaper window) are not widgets
// and are left alone, like any application window.
// (`closeIfOpen()` on the same target is the close-window key's, see quickshell/close-widget.sh.)
QtObject {
    id: root

    // Closes every other widget: all running shells but this process, each asked in the background.
    function closeOthers() {
        Quickshell.execDetached(["sh", "-c",
            'for pid in $(qs list --all 2>/dev/null | sed -n "s/^ *Process ID: *//p"); do '
            + '[ "$pid" = "$1" ] || qs ipc --pid "$pid" call widget closeForOther >/dev/null 2>&1 & done; wait',
            "sh", String(Quickshell.processId)])
    }

    // A widget opened (+1) or closed (-1): Hyprland keeps the window under it "active", so hyprland.lua's
    // widgetFocus() draws its border as inactive while any widget is open (a count, so that widgets
    // that swap stay right). Call it once per open and once per close.
    function noteOpened(open) {
        Quickshell.execDetached(["hyprctl", "eval", "widgetFocus(" + (open ? 1 : -1) + ")"])
    }

    // Only the bar's menus (what a widget that ignores the rule still does, as before).
    function closeBarPanels() {
        Quickshell.execDetached(["qs", "-c", "status-bar", "ipc", "call", "bar", "closePanels"])
    }
}
