pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Is the Lucent plugin loaded in the running Hyprland? (~/Documents/Code/Lucent)
//
// With Lucent, the compositor leaves Quickshell's own surfaces out of the captures Quickshell
// makes, so the glass can use a capture as the background as it is ("clean" mode, see
// GlassBackdrop). Without it (not installed, a Hyprland update the plugin does not match, a
// nested test session) the glass keeps estimating and subtracting its own surfaces.
//
// The plugin writes a marker file into this Hyprland instance's runtime directory when it loads
// and removes it when it unloads. The directory is named after HYPRLAND_INSTANCE_SIGNATURE, which is
// new for every Hyprland start, so a marker left by a crashed instance can never be mistaken for a
// live one.
//
// The plugin used to be called "pane" (marker `pane-active`). A Hyprland that was started before the
// rename still has that build loaded, so both markers count. Remove `legacyPath` once Hyprland has
// been restarted with the renamed plugin.
Singleton {
    id: root

    readonly property string signature: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || ""
    readonly property string dir:
        signature === "" ? "" : (Quickshell.env("XDG_RUNTIME_DIR") || "") + "/hypr/" + signature + "/"
    readonly property string path: dir === "" ? "" : dir + "lucent-active"
    readonly property string legacyPath: dir === "" ? "" : dir + "pane-active"

    // True while a marker exists.
    readonly property bool active: (path !== "" && file.loaded) || (legacyPath !== "" && legacyFile.loaded)

    FileView {
        id: file
        path: root.path
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }

    FileView {
        id: legacyFile
        path: root.legacyPath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }

    // The marker may appear after this process started (the plugin loads with the config), and a
    // missing file cannot be watched: look again every few seconds. Cheap: one failed open each.
    Timer {
        running: root.path !== ""
        interval: 3000
        repeat: true
        onTriggered: {
            file.reload()
            legacyFile.reload()
        }
    }
}
