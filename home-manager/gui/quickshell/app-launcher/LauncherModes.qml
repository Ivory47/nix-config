pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

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
        writeTimer.restart()
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

    property var ownWrites: []

    function parse(text) {
        if (ownWrites.indexOf(text) >= 0)
            return
        try {
            const obj = JSON.parse(text)
            const clean = {}
            if (obj && typeof obj === "object" && !Array.isArray(obj)) {
                for (const k of Object.keys(obj))
                    if (obj[k] === "window")
                        clean[k] = "window"
            }
            modes = clean
        } catch (e) {
            console.warn("modes.json is not valid JSON, ignoring it:", e)
        }
    }

    Timer {
        id: writeTimer
        interval: 30
        onTriggered: {
            const text = JSON.stringify(root.modes, null, 2) + "\n"
            root.ownWrites = root.ownWrites.concat([text]).slice(-8)
            file.setText(text)
        }
    }

    FileView {
        id: file
        path: root.path
        blockLoading: true
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: root.parse(text())
        Component.onCompleted: if (loaded) root.parse(text())
        onSaveFailed: error => console.warn("modes.json could not be saved:", error)
    }

    // A file that does not exist yet cannot be watched: look for it until it appears.
    Timer {
        running: !file.loaded
        interval: 2000
        repeat: true
        onTriggered: file.reload()
    }

    // The folder has to exist for the first write.
    Process {
        running: true
        command: ["mkdir", "-p", root.dir]
    }
}
