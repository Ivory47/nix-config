pragma Singleton

import QtQuick
import Quickshell

// "One widget at a time". Each shell runs in its own process, so a widget that opens tells the others
// to close through their IPC handlers (a `qs ipc call`, fire and forget; a shell that is not running
// just fails quietly).
//
// GlassPopup calls closeOthers() whenever it opens, so every popup built on it follows this by default.
// A new widget joins in two steps:
//  1. add its shell here (`config` = the `qs -c` name, `target` = its IpcHandler target, `hide` = the
//     function there that closes its OVERLAYS: it must not close normal windows or be a toggle);
//  2. be a GlassPopup (nothing more to do), or call Widgets.closeOthers("<config>") when it opens.
// A widget that should ignore the rule sets `exclusive: false` on its GlassPopup (the clipboard does) and
// is simply not listed here, so nobody closes it either.
// Normal windows (the settings window, the wallpaper window) are not widgets in this sense and are
// left alone: they are like any application window.
QtObject {
    id: root

    readonly property var shells: [
        { config: "app-launcher", target: "launcher", hide: "hide" },
        { config: "settings", target: "settings", hide: "hideOverlay" },
        { config: "wallpapers", target: "wallpapers", hide: "hideOverlay" },
        // The bar's menus and panels.
        { config: "status-bar", target: "bar", hide: "closePanels" }
    ]

    // Closes every listed widget except `self` (a `config` name).
    function closeOthers(self) {
        for (const s of shells) {
            if (s.config !== self)
                Quickshell.execDetached(["qs", "-c", s.config, "ipc", "call", s.target, s.hide])
        }
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
