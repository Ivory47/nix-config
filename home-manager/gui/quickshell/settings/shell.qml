import Quickshell
import Quickshell.Io
import qs.shared

// The settings app, in two forms that share SettingsView.qml: the full-screen overlay with the veil
// (Settings.qml, the default) and a normal window (SettingsWindow.qml). Only one is open at a time.
ShellRoot {
    Settings {
        id: overlay
    }

    SettingsWindow {
        id: window
    }

    ExclusiveShown {
        a: overlay
        b: window
    }

    IpcHandler {
        target: "settings"

        // Asked by the Super+C bind (hyprland.lua): close the overlay instead of the focused window.
        // The OVERLAY only: the window is a normal window, which Super+C closes like any other.
        // (A function and not a property: a property logs a warning at every change.)
        function isOpen(): bool {
            return overlay.shown
        }

        // The overlay.
        function toggle() {
            overlay.shown = !overlay.shown
        }

        function show() {
            overlay.shown = true
        }

        // The normal window.
        function toggleWindow() {
            window.shown = !window.shown
        }

        function showWindow() {
            window.shown = true
        }

        // Both.
        function hide() {
            overlay.shown = false
            window.shown = false
        }
    }
}
