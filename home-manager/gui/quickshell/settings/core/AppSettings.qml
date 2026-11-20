pragma Singleton

import QtQuick
import Quickshell
import qs.shared

// The settings app's own settings (AppDefaults: the keyboard mode, the cursor, the vim keys) with the
// changes made in it laid over them, and the store that changes them. Its own file, apart from the
// theme's: ~/.config/quickshell-settings/settings-app.json, only what differs from the defaults, nested
// like AppDefaults: {"keyboard": {"mode": "classic"}, "keys": {"down": ["j", "Down", "n"]}}.
// In memory `values` is flat by path ("keyboard.mode", "keys.down"). A value equal to the default is
// removed. Takes part in undo / redo (SettingsHistory). ThemeStore hands it the keys it `owns`, so the
// rows (SettingsRow, ChoiceField, KeysField) work with it as with the theme.
Singleton {
    id: root

    readonly property string path:
        (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config"))
        + "/quickshell-settings/settings-app.json"

    property var values: ({})

    readonly property string mode: typeof values["keyboard.mode"] === "string" ? values["keyboard.mode"] : AppDefaults.keyboard.mode
    readonly property string cursor: typeof values["keyboard.cursor"] === "string" ? values["keyboard.cursor"] : AppDefaults.keyboard.cursor
    readonly property bool vim: mode !== "classic"

    // action -> its keys (["j", "Down"]).
    readonly property var keys: {
        const out = {}
        for (const a in AppDefaults.keys) {
            const v = values["keys." + a]
            out[a] = Array.isArray(v) ? v.filter(k => typeof k === "string") : AppDefaults.keys[a]
        }
        return out
    }

    // The key binding whose editor is open under its row (KeysField), "" for none: one at a time.
    property string openBinding: ""

    function owns(key) {
        return key.startsWith("keyboard.") || key.startsWith("keys.")
    }

    function value(key) {
        const [group, sub] = key.split(".")
        return group === "keys" ? keys[sub] : sub === "mode" ? mode : cursor
    }

    function defaultOf(key) {
        const [group, sub] = key.split(".")
        return AppDefaults[group] ? AppDefaults[group][sub] : undefined
    }

    function isSet(key) {
        return values[key] !== undefined
    }

    function set(key, v) {
        const next = Object.assign({}, values)
        if (JSON.stringify(v) === JSON.stringify(defaultOf(key)))
            delete next[key]
        else
            next[key] = v
        values = next
        commit()
    }

    function reset(key) {
        resetKeys([key])
    }

    function resetKeys(list) {
        const next = Object.assign({}, values)
        for (const k of list)
            delete next[k]
        values = next
        commit()
    }

    function commit() {
        SettingsHistory.committed(root)
        file.save(nest(values))
    }

    function nest(flat) {
        const out = {}
        for (const k in flat) {
            const [group, sub] = k.split(".")
            out[group] = out[group] || {}
            out[group][sub] = flat[k]
        }
        return out
    }

    function flatten(obj) {
        const out = {}
        for (const group of ["keyboard", "keys"])
            for (const sub in (obj && typeof obj[group] === "object" ? obj[group] : {}))
                out[group + "." + sub] = obj[group][sub]
        return out
    }

    // The first setting (page order) that differs between two states (where undo / redo shows it).
    function locate(from, to) {
        const e = SettingsIndex.entries.find(e => JSON.stringify(from[e.spec.key]) !== JSON.stringify(to[e.spec.key]))
        return e ? { catId: e.catId, key: e.spec.key } : null
    }

    Component.onCompleted: SettingsHistory.register(root, () => root.values, v => {
        root.values = v
        root.commit()
    }, locate)

    JsonFile {
        id: file
        path: root.path
        name: "settings-app.json"
        onParsed: value => {
            // (Through the signal a list arrives as a Qt sequence, not a JS array: plain JSON data again.)
            root.values = root.flatten(JSON.parse(JSON.stringify(value)))
            Qt.callLater(() => SettingsHistory.rebase(root))
        }
        onMissing: root.values = ({})
        onInvalid: root.values = ({})
    }
}
