pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What the user has set per wallpaper: its tags, and the colour / scheme type / mode last picked.
// Lives outside the nix store (survives `hms`), in
//   $XDG_CONFIG_HOME/quickshell-wallpapers/wallpapers.json
//   { "tags":   { "<file name>": ["calm", "dark"] },
//     "choice": { "<file name>": { "index": 0, "type": "scheme-tonal-spot", "mode": "dark" } } }
// Entries are keyed by file name, so renaming a file loses its tags.
// Same pattern as settings/ThemeStore.qml: edits are kept in memory at once and written after a
// short pause; a read of our own write is ignored.
Singleton {
    id: root

    readonly property string dir:
        (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config"))
        + "/quickshell-wallpapers"
    readonly property string path: dir + "/wallpapers.json"

    property var tags: ({})
    property var choices: ({})

    readonly property string defaultType: "scheme-tonal-spot"
    readonly property string defaultMode: "dark"

    // ---- tags -------------------------------------------------------------------------------

    function tagsOf(name) {
        return tags[name] || []
    }

    // "calm, Dark mode" -> ["calm", "dark mode"]
    function parseTags(text) {
        const out = []
        for (const part of String(text).split(",")) {
            const t = part.trim().toLowerCase().replace(/^#+/, "").replace(/\s+/g, " ")
            if (t.length > 0 && out.indexOf(t) < 0)
                out.push(t)
        }
        return out
    }

    function addTags(name, text) {
        const add = parseTags(text)
        if (add.length === 0)
            return
        const have = tagsOf(name)
        const merged = have.concat(add.filter(t => have.indexOf(t) < 0))
        if (merged.length === have.length)
            return
        const next = Object.assign({}, tags)
        next[name] = merged
        tags = next
        commit()
    }

    function removeTag(name, tag) {
        const have = tagsOf(name)
        if (have.indexOf(tag) < 0)
            return
        const left = have.filter(t => t !== tag)
        const next = Object.assign({}, tags)
        if (left.length > 0)
            next[name] = left
        else
            delete next[name]
        tags = next
        commit()
    }

    // The built-in tag that means "favourite": a star on the cards, a pinned filter, and the overlay shows
    // the favourites first. (An ordinary tag: it is in the file like any other.)
    readonly property string favouriteTag: "favourite"

    function isFavourite(name) {
        return tagsOf(name).indexOf(favouriteTag) >= 0
    }

    function toggleFavourite(name) {
        if (isFavourite(name))
            removeTag(name, favouriteTag)
        else
            addTags(name, favouriteTag)
    }

    function favouriteCount(names) {
        let n = 0
        for (const name of names)
            if (isFavourite(name))
                n++
        return n
    }

    // Existing tags to offer while a tag is typed. `known` is [{tag, count}] (all wallpapers), `have` the
    // tags the wallpaper has already, `typed` what is in the field: only its last comma-separated part
    // counts ("calm, wa" looks for "wa"). The built-in favourite tag is left out (it has its star).
    // Tags that START with what is typed come first, then the most used.
    function suggestTags(known, have, typed, limit) {
        const token = String(typed).split(",").pop().trim().toLowerCase().replace(/^#+/, "")
        const out = known.filter(t => t.tag !== favouriteTag && have.indexOf(t.tag) < 0
                                  && (token === "" || t.tag.indexOf(token) >= 0))
        out.sort((a, b) => ((b.tag.startsWith(token) ? 1 : 0) - (a.tag.startsWith(token) ? 1 : 0))
                           || (b.count - a.count) || a.tag.localeCompare(b.tag))
        return out.slice(0, limit)
    }

    // Every tag in use with the number of wallpapers that have it (for the files in `names`, so a
    // tag of a file that is gone does not show), most used first, then alphabetical.
    function allTags(names) {
        const count = {}
        for (const n of names)
            for (const t of tagsOf(n))
                count[t] = (count[t] || 0) + 1
        return Object.keys(count)
            .map(t => ({ tag: t, count: count[t] }))
            .sort((a, b) => (b.count - a.count) || a.tag.localeCompare(b.tag))
    }

    // ---- colour choice ----------------------------------------------------------------------

    function choiceOf(name) {
        const c = choices[name] || {}
        return {
            index: (typeof c.index === "number" && c.index >= 0) ? Math.floor(c.index) : 0,
            type: typeof c.type === "string" ? c.type : defaultType,
            mode: c.mode === "light" ? "light" : defaultMode
        }
    }

    function setChoice(name, index, type, mode) {
        const old = choiceOf(name)
        if (old.index === index && old.type === type && old.mode === mode && choices[name] !== undefined)
            return
        const next = Object.assign({}, choices)
        if (index === 0 && type === defaultType && mode === defaultMode)
            delete next[name]
        else
            next[name] = { index: index, type: type, mode: mode }
        choices = next
        commit()
    }

    // ---- file -------------------------------------------------------------------------------

    property var ownWrites: []

    function commit() {
        writeTimer.restart()
    }

    function parse(text) {
        if (ownWrites.indexOf(text) >= 0)
            return
        try {
            const obj = JSON.parse(text)
            tags = (obj && typeof obj.tags === "object" && obj.tags !== null) ? obj.tags : ({})
            choices = (obj && typeof obj.choice === "object" && obj.choice !== null) ? obj.choice : ({})
        } catch (e) {
            console.warn("wallpapers.json is not valid JSON, ignoring it:", e)
        }
    }

    Timer {
        id: writeTimer
        interval: 30
        onTriggered: {
            const text = JSON.stringify({ tags: root.tags, choice: root.choices }, null, 2) + "\n"
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
        onSaveFailed: error => console.warn("wallpapers.json could not be saved:", error)
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
