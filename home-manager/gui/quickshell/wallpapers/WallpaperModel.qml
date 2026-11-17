import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

// The wallpapers in ~/Pictures/Wallpapers (live: files that are added or removed show up), the
// search, and which one is on the screen now.
//
//  - entries: every image, { name, base (without extension), path, size, modified, kind }.
//  - filtered: the entries that match `query` and every tag in `activeTags`. Each word of the query
//    must match: "#word" the start of one of the tags, any other word a part of the file name or
//    of a tag. Case does not matter.
//  - current: the file name that awww shows now ("" if unknown), see refreshCurrent().
QtObject {
    id: root

    readonly property string folder: (Quickshell.env("HOME") || "") + "/Pictures/Wallpapers"

    property string query: ""
    property var activeTags: []

    // `store` is the WallpaperStore singleton (passed in: a plain object cannot see it by name).
    required property var store

    property var entries: {
        const out = []
        if (files.status !== FolderListModel.Ready)
            return out
        for (let i = 0; i < files.count; ++i) {
            const name = files.get(i, "fileName")
            const dot = name.lastIndexOf(".")
            out.push({
                name: name,
                base: dot > 0 ? name.substring(0, dot) : name,
                path: files.get(i, "filePath"),
                size: files.get(i, "fileSize"),
                modified: files.get(i, "fileModified").getTime(),
                kind: dot > 0 ? name.substring(dot + 1).toUpperCase() : ""
            })
        }
        return out
    }

    property var filtered: {
        const words = query.toLowerCase().split(/\s+/).filter(w => w.length > 0)
        const need = activeTags
        const tagsOf = store.tagsOf
        return entries.filter(e => {
            const tags = tagsOf(e.name)
            for (const t of need)
                if (tags.indexOf(t) < 0)
                    return false
            const lname = e.name.toLowerCase()
            for (const w of words) {
                if (w.charAt(0) === "#") {
                    const p = w.substring(1)
                    if (!tags.some(t => t.startsWith(p)))
                        return false
                } else if (lname.indexOf(w) < 0 && !tags.some(t => t.indexOf(w) >= 0)) {
                    return false
                }
            }
            return true
        })
    }

    // The tags of the files that exist, with counts.
    readonly property var tagList: store.allTags(entries.map(e => e.name))

    function indexOfName(name) {
        for (let i = 0; i < filtered.length; ++i)
            if (filtered[i].name === name)
                return i
        return -1
    }

    // ---- what awww shows now ----------------------------------------------------------------

    property string current: ""

    function refreshCurrent() {
        if (!query_.running)
            query_.running = true
    }

    // `awww query` prints "<output>: <size>, scale: ..., currently displaying: image: <path>" per output.
    property var queryProc: Process {
        id: query_
        command: ["awww", "query"]
        stdout: StdioCollector {
            id: queryOut
        }
        onExited: (code, status) => {
            const m = /currently displaying: image: (.+)/.exec(queryOut.text)
            root.current = m ? m[1].trim().replace(/^.*\//, "") : ""
        }
    }

    property var files: FolderListModel {
        folder: "file://" + root.folder
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif", "*.bmp"]
        caseSensitive: false
        showDirs: false
        sortField: FolderListModel.Name
    }
}
