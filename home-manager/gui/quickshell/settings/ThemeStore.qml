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

    // The default of a key: "background", or a path into a group ("glassBar.frost").
    function defaultOf(key) {
        const dot = key.indexOf(".")
        if (dot < 0)
            return ThemeDefaults[key]
        const group = ThemeDefaults[key.slice(0, dot)]
        return group ? group[key.slice(dot + 1)] : undefined
    }

    // Settings files written before the glass looks and the shadows were groups have flat keys
    // ("glassBarTintStrength", "popupShadowOpacity"): rewritten once to paths ("glassBar.tintStrength").
    // Only the settings app writes the file, so only it does this; the other shells read the result.
    readonly property var legacyKey: /^(glassDefault|glassPanel|glassBar|popupShadow|notificationShadow)([A-Z]\w*)$/
    function migrate() {
        const vals = ThemeFromSettingsApp.values
        const old = Object.keys(vals).filter(k => legacyKey.test(k) && k !== "glassPanelLook" && k !== "glassBarLook")
        if (old.length === 0)
            return
        const next = Object.assign({}, vals)
        for (const k of old) {
            const m = legacyKey.exec(k)
            const path = m[1] + "." + m[2].charAt(0).toLowerCase() + m[2].slice(1)
            // (A value equal to its default is dropped, as set() does.)
            if (next[path] === undefined && !same(vals[k], defaultOf(path)))
                next[path] = vals[k]
            delete next[k]
        }
        ThemeFromSettingsApp.values = next
        commit()
    }
    property Connections migrateOnLoad: Connections {
        target: ThemeFromSettingsApp
        function onValuesChanged() { root.migrate() }
    }
    Component.onCompleted: migrate()

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
