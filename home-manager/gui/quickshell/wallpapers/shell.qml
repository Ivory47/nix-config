import Quickshell
import Quickshell.Io

// The wallpaper picker in two forms: a normal window with glass (WallpaperPicker.qml, from the app
// launcher) and a full-screen overlay with a big picture you scroll through (WallpaperOverlay.qml, Super+W).
// One is open at a time. IPC target `wallpapers`: `toggle` / `show`... are for the window (they were
// before the overlay existed), `toggleOverlay` for the overlay, `hide` closes both.
// (`qs ipc call ... show` only prints the IPC listing here; use `toggle` / `toggleOverlay` to open.)
ShellRoot {
    WallpaperPicker {
        id: window
    }

    WallpaperOverlay {
        id: overlay
    }

    IpcHandler {
        target: "wallpapers"

        function isOpen(): bool {
            return window.shown || overlay.shown
        }

        // The window.
        function toggle() {
            overlay.shown = false
            window.shown = !window.shown
        }

        function show() {
            overlay.shown = false
            window.shown = true
        }

        // The overlay.
        function toggleOverlay() {
            window.shown = false
            overlay.shown = !overlay.shown
        }

        function showOverlay() {
            window.shown = false
            overlay.shown = true
        }

        // The overlay only (what Widgets.qml asks when another widget opens; the window stays).
        function hideOverlay() {
            overlay.shown = false
        }

        function hide() {
            window.shown = false
            overlay.shown = false
        }
    }
}
