pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.shared

// Apps that can be opened in two ways: as an overlay (their normal entry, e.g. the settings as a
// full-screen popup) or as a normal window. An app says so by having a desktop ACTION with the id
// `window` ("Open as window"; see default.nix). Such an app gets a toggle in the launcher, and the
// choice is remembered here, per app, in
//   $XDG_CONFIG_HOME/quickshell-launcher/modes.json     { "<desktop id>": "window" }
// (only apps set to "window" are listed; the default is the overlay, i.e. the entry's own exec).
Singleton {
    id: root

    readonly property string dir:
        (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config"))
        + "/quickshell-launcher"
    readonly property string path: dir + "/modes.json"

    // desktop id -> "window". Replaced as a whole, so bindings that read it re-evaluate.
    property var modes: ({})

    // The action that opens `app` as a window, or null if it has only one way.
    function windowAction(app) {
        if (!app || !app.actions)
            return null
        for (const a of app.actions) {
            if (a.id === "window")
                return a
        }
        return null
    }

    function hasChoice(app) {
        return windowAction(app) !== null
    }

    function isWindow(app) {
        return !!app && modes[app.id] === "window" && windowAction(app) !== null
    }

    function toggle(app) {
        if (!hasChoice(app))
            return
        const next = Object.assign({}, modes)
        if (next[app.id] === "window")
            delete next[app.id]
        else
            next[app.id] = "window"
        modes = next
        file.save(root.modes)
    }

    // Opens the app the way it is set.
    function launch(app) {
        if (!app)
            return
        const action = isWindow(app) ? windowAction(app) : null
        if (action)
            action.execute()
        else
            app.execute()
    }

    JsonFile {
        id: file
        path: root.path
        name: "modes.json"
        // Only "window" is stored; anything else in the file is dropped.
        onParsed: value => {
            const clean = {}
            if (value && typeof value === "object" && !Array.isArray(value)) {
                for (const k of Object.keys(value))
                    if (value[k] === "window")
                        clean[k] = "window"
            }
            modes = clean
        }
    }
}
