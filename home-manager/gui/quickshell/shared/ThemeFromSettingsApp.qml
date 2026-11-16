pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The values the settings app has set, read from its own file. Theme.qml layers them over
// ThemeDefaults.qml; a key that is missing (or has the wrong type) falls back to the default.
//
// The file is outside the nix store, so it survives `hms`, and every Quickshell process
// (status bar, launcher, clipboard, settings app) watches it: a change shows up in all of them
// at once. Only the settings app writes it. Format: one flat JSON object with only the changed
// keys, named like the properties of ThemeDefaults.qml, e.g. {"background": "#101020", "radiusLarge": 12}.
Singleton {
    id: root

    readonly property string path:
        (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config"))
        + "/quickshell-settings/settings-app-theme.json"

    // The parsed file: key -> value. Replaced as a whole, so bindings that read it re-evaluate.
    property var values: ({})

    // Typed lookups: the settings app's value if it is valid, else `fallback`.
    function color(key, fallback) {
        const v = values[key]
        return (typeof v === "string" && /^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(v)) ? v : fallback
    }
    function real(key, fallback) {
        const v = values[key]
        return (typeof v === "number" && isFinite(v)) ? v : fallback
    }
    function integer(key, fallback) {
        const v = values[key]
        return (typeof v === "number" && isFinite(v)) ? Math.round(v) : fallback
    }
    function bool(key, fallback) {
        const v = values[key]
        return typeof v === "boolean" ? v : fallback
    }

    // Texts the settings app wrote itself (it keeps the last few). Reading one of them back would
    // replace newer changes it holds in memory with an older state, so parse() skips them.
    property var ownWrites: []
    function noteOwnWrite(text) {
        ownWrites = ownWrites.concat([text]).slice(-8)
    }

    function parse(text) {
        if (ownWrites.indexOf(text) >= 0)
            return
        try {
            const obj = JSON.parse(text)
            values = (obj !== null && typeof obj === "object" && !Array.isArray(obj)) ? obj : ({})
        } catch (e) {
            console.warn("settings-app-theme.json is not valid JSON, using the defaults:", e)
            values = ({})
        }
    }

    FileView {
        id: file
        path: root.path
        // Loaded at construction, so there is no flash of the defaults.
        blockLoading: true
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: root.parse(text())
        onLoadFailed: root.values = ({})
        Component.onCompleted: if (loaded) root.parse(text())
    }

    // A file that does not exist yet is not watched (Quickshell cannot watch a missing file):
    // look for it every two seconds until it appears (the settings app creates it on first save).
    Timer {
        running: !file.loaded
        interval: 2000
        repeat: true
        onTriggered: file.reload()
    }
}
