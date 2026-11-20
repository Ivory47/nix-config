pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The values the settings app has set, read from its own file. Theme.qml layers them over
// ThemeDefaults.qml; a key that is missing (or has the wrong type) falls back to the default.
//
// The file is outside the nix store, so it survives `hms`, and every Quickshell process
// (status bar, launcher, clipboard, settings app) watches it: a change shows up in all of them
// at once. Only the settings app writes it. Format: a JSON object with only the changed keys, named
// like the properties of ThemeDefaults.qml, the groups (glass looks, shadows) as objects of their own:
// {"background": "#101020", "radiusLarge": 12, "glassBar": {"tintStrength": 0.45}}.
// In memory (`values`) a grouped key is a path, "glassBar.tintStrength": `flatten` and `nest` convert
// between the two when the file is read and written (writeValues).
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

    function isGroup(v) {
        return v !== null && typeof v === "object" && !Array.isArray(v)
    }

    // {"glassBar": {"frost": 1}} -> {"glassBar.frost": 1} (one level: groups hold plain values).
    function flatten(obj) {
        const out = {}
        for (const k of Object.keys(obj)) {
            if (isGroup(obj[k])) {
                for (const sub of Object.keys(obj[k]))
                    out[k + "." + sub] = obj[k][sub]
            } else {
                out[k] = obj[k]
            }
        }
        return out
    }

    // The reverse, for the file: {"glassBar.frost": 1} -> {"glassBar": {"frost": 1}}.
    function nest(flat) {
        const out = {}
        for (const k of Object.keys(flat)) {
            const dot = k.indexOf(".")
            if (dot < 0) {
                out[k] = flat[k]
            } else {
                const group = k.slice(0, dot)
                if (!isGroup(out[group]))
                    out[group] = {}
                out[group][k.slice(dot + 1)] = flat[k]
            }
        }
        return out
    }

    // Writes these values (paths in memory) to the file, nested.
    function writeValues(flat) {
        file.write(nest(flat))
    }

    // The file. The settings app writes it through `file.save()` / `file.write()` (ThemeStore); what it
    // wrote itself is not read back, so a late watcher event cannot undo newer changes it holds in memory.
    // (A file that does not exist yet is looked for every 2 s: the settings app creates it on first save.)
    readonly property alias file: file
    JsonFile {
        id: file
        path: root.path
        name: "settings-app-theme.json"
        onParsed: value => root.values = (value !== null && typeof value === "object" && !Array.isArray(value)) ? root.flatten(value) : ({})
        onMissing: root.values = ({})
        onInvalid: root.values = ({})   // the defaults
    }
}
