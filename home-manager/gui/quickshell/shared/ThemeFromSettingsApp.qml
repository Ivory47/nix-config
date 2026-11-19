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
    function text(key, fallback) {
        const v = values[key]
        return typeof v === "string" ? v : fallback
    }
    function bool(key, fallback) {
        const v = values[key]
        return typeof v === "boolean" ? v : fallback
    }

    // The file. The settings app writes it through `file.save()` / `file.write()` (ThemeStore); what it
    // wrote itself is not read back, so a late watcher event cannot undo newer changes it holds in memory.
    // (A file that does not exist yet is looked for every 2 s: the settings app creates it on first save.)
    readonly property alias file: file
    JsonFile {
        id: file
        path: root.path
        name: "settings-app-theme.json"
        onParsed: value => root.values = (value !== null && typeof value === "object" && !Array.isArray(value)) ? value : ({})
        onMissing: root.values = ({})
        onInvalid: root.values = ({})   // the defaults
    }
}
