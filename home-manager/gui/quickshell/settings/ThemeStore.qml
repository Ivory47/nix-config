pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
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
            return Qt.colorEqual(a, b)
        if (typeof a === "number")
            return Math.abs(a - b) < 1e-9
        return a === b
    }

    // "#rrggbb", or "#aarrggbb" (Qt's order) when `alpha`.
    function colorString(c, alpha) {
        const h = v => Math.round(v * 255).toString(16).padStart(2, "0")
        return "#" + (alpha ? h(c.a) : "") + h(c.r) + h(c.g) + h(c.b)
    }

    function preview(key, value) {
        const next = Object.assign({}, ThemeFromSettingsApp.values)
        if (same(value, ThemeDefaults[key]))
            delete next[key]
        else
            next[key] = value
        ThemeFromSettingsApp.values = next
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

    function resetAll() {
        ThemeFromSettingsApp.values = ({})
        commit()
    }

    // Writes after a short pause: a burst of changes becomes one write.
    Timer {
        id: writeTimer
        interval: 30
        onTriggered: {
            const text = JSON.stringify(ThemeFromSettingsApp.values, null, 2) + "\n"
            ThemeFromSettingsApp.noteOwnWrite(text)
            out.setText(text)
        }
    }

    FileView {
        id: out
        path: ThemeFromSettingsApp.path
        printErrors: false
        onSaveFailed: error => console.warn("settings-app-theme.json could not be saved:", error)
    }

    // The folder has to exist for the first write.
    Process {
        running: true
        command: ["mkdir", "-p", ThemeFromSettingsApp.path.replace(/\/[^\/]*$/, "")]
    }
}
