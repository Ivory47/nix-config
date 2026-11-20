pragma Singleton

import QtQuick
import Quickshell
import qs.shared

// Where the settings app changes the theme: the same file the shells read (ThemeFromSettingsApp).
//  - preview(key, value): changes the value in this process only (the sliders use it while they are
//    dragged, so that nothing is written 60 times a second);
//  - commit(): writes the file, and the other shells follow;
//  - set(key, value) = both. A value equal to the default is removed from the file instead.
Singleton {
    id: root

    readonly property var values: ThemeFromSettingsApp.values

    function isSet(key) {
        return values[key] !== undefined
    }

    function same(a, b) {
        if (typeof a === "string")
            return a.charAt(0) === "#" ? Qt.colorEqual(a, b) : a === b
        if (typeof a === "number")
            return Math.abs(a - b) < 1e-9
        return a === b
    }

    // "#rrggbb", or "#aarrggbb" (Qt's order) when `alpha`.
    function colorString(c, alpha) {
        const h = v => Math.round(v * 255).toString(16).padStart(2, "0")
        return "#" + (alpha ? h(c.a) : "") + h(c.r) + h(c.g) + h(c.b)
    }

    // The default of a key: "background", or a path into a group ("glassBar.frost"). A glass look knows
    // its own (a widget's unset values are the default look's, live).
    function defaultOf(key) {
        const dot = key.indexOf(".")
        if (dot < 0)
            return ThemeDefaults[key]
        const group = key.slice(0, dot)
        const sub = key.slice(dot + 1)
        if (Theme[group] && typeof Theme[group].defaultOf === "function")
            return Theme[group].defaultOf(sub)
        return ThemeDefaults[group] ? ThemeDefaults[group][sub] : undefined
    }

    // Old settings files, rewritten once (only the settings app writes the file; the other shells read
    // the result):
    //  - flat keys from before the groups ("glassBarTintStrength", "popupShadowOpacity", "glassBarLook")
    //    become paths ("glassBar.tintStrength", "glassBar.look");
    //  - the one look all panels shared (`glassPanel`, used while `glassPanel.look` was "own") goes to
    //    each widget it covered; without "own" it is dropped.
    // Values equal to their default are dropped, as set() does.
    readonly property var legacyKey: /^(glassDefault|glassPanel|glassBar|popupShadow|notificationShadow)([A-Z]\w*)$/
    readonly property var panelWidgets: ["glassLauncher", "glassClipboard", "glassSettings", "glassWallpapers", "glassNotifications"]
    function migrate() {
        const vals = ThemeFromSettingsApp.values
        const keys = Object.keys(vals)
        if (!keys.some(k => legacyKey.test(k) || k.startsWith("glassPanel.")))
            return
        const next = Object.assign({}, vals)
        for (const k of keys.filter(k => legacyKey.test(k))) {
            const m = legacyKey.exec(k)
            const path = m[1] + "." + m[2].charAt(0).toLowerCase() + m[2].slice(1)
            if (next[path] === undefined)
                next[path] = vals[k]
            delete next[k]
        }
        const panelOwn = next["glassPanel.look"] === "own"
        for (const k of Object.keys(next).filter(k => k.startsWith("glassPanel."))) {
            const sub = k.slice("glassPanel.".length)
            if (panelOwn)
                for (const w of panelWidgets)
                    if (next[w + "." + sub] === undefined)
                        next[w + "." + sub] = next[k]
            delete next[k]
        }
        for (const k of Object.keys(next))
            if (k.indexOf(".") > 0 && k.slice(k.indexOf(".") + 1) !== "look" && same(next[k], defaultOf(k)))
                delete next[k]
        ThemeFromSettingsApp.values = next
        commit()
        SettingsHistory.rebase(root)
    }
    property Connections migrateOnLoad: Connections {
        target: ThemeFromSettingsApp
        function onValuesChanged() { root.migrate() }
    }
    // A file read (the app's own writes are not read back) is not an undoable step.
    property Connections rebaseOnLoad: Connections {
        target: ThemeFromSettingsApp.file
        function onParsed() { Qt.callLater(() => SettingsHistory.rebase(root)) }
    }
    // The first setting (page order) whose value differs between two states.
    function locate(from, to) {
        const eq = (x, y) => x === undefined || y === undefined ? x === y : same(x, y)
        const e = SettingsIndex.entries.find(e => !eq(from[e.spec.key], to[e.spec.key]))
        return e ? { catId: e.catId, key: e.spec.key } : null
    }

    Component.onCompleted: {
        SettingsHistory.register(root, () => ThemeFromSettingsApp.values, v => {
            ThemeFromSettingsApp.values = v
            commit()
        }, locate)
        migrate()
    }

    function preview(key, value) {
        const next = Object.assign({}, ThemeFromSettingsApp.values)
        if (same(value, defaultOf(key)))
            delete next[key]
        else
            next[key] = value
        ThemeFromSettingsApp.values = next
    }

    // The colour picker that is open (a Theme key, "" for none): one at a time.
    property string openColor: ""

    // For values that other processes show (the bar): changes it and writes while the drag goes on,
    // at most every 50 ms (commit() would wait for the drag to stop).
    function setLive(key, value) {
        preview(key, value)
        if (!liveTimer.running)
            liveTimer.start()
    }

    function commit() {
        SettingsHistory.committed(root)
        writeTimer.restart()
    }

    function set(key, value) {
        preview(key, value)
        commit()
    }

    function reset(key) {
        const next = Object.assign({}, ThemeFromSettingsApp.values)
        delete next[key]
        ThemeFromSettingsApp.values = next
        commit()
    }

    // Several at once, one write ("Reset page").
    function resetKeys(keys) {
        const next = Object.assign({}, ThemeFromSettingsApp.values)
        for (const k of keys)
            delete next[k]
        ThemeFromSettingsApp.values = next
        commit()
    }

    function resetAll() {
        ThemeFromSettingsApp.values = ({})
        commit()
    }

    // Writes after a short pause: a burst of changes becomes one write.
    Timer {
        id: writeTimer
        interval: 30
        onTriggered: ThemeFromSettingsApp.writeValues(ThemeFromSettingsApp.values)
    }

    Timer {
        id: liveTimer
        interval: 50
        onTriggered: writeTimer.restart()
    }
}
