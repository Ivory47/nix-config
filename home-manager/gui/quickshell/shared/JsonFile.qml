import QtQuick
import Quickshell
import Quickshell.Io

// A JSON file that a store keeps its state in (settings, tags, history, caches): reading, watching and
// writing in one place, so that a store has only its own parsing and its own data.
//
//   JsonFile {
//       id: file
//       path: root.dir + "/thing.json"
//       onParsed: value => root.items = value.items ?? []
//   }
//   ... file.save(root.state)      // later, debounced
//
// Reading: the file is loaded when the object is created (blocking, so there is no flash of defaults),
// watched for changes (`watch`; it works from any number of processes) and, while it does not exist yet,
// looked for every `retryInterval` ms (Quickshell cannot watch a missing file). `parsed(value)` is the
// parsed JSON; `missing()` when there is no file; `invalid(error)` for broken JSON (a warning is logged).
// What this object wrote itself is not read back (`parsed` is not emitted for it): a late file-watcher
// event must not replace a newer state the store holds in memory.
//
// Writing: `save(value)` waits `writeDelay` ms and merges bursts into one write; `write(value)` writes at
// once. The folder is created before the first write. `saved()` / `saveFailed(error)` follow.
Scope {
    id: root

    required property string path
    // For messages.
    property string name: path.split("/").pop()
    property bool watch: true
    property int retryInterval: 2000    // 0: do not look for a missing file
    property int writeDelay: 30
    property int indent: 2               // 0 for a compact file
    property bool atomicWrites: false

    readonly property bool loaded: file.loaded
    readonly property string dir: path.replace(/\/[^\/]*$/, "")

    signal parsed(var value)
    signal missing()
    signal invalid(var error)
    signal saved()
    signal saveFailed(string error)

    function reload() {
        file.reload()
    }

    function save(value) {
        d.pending = value
        d.hasPending = true
        writeTimer.restart()
    }

    function write(value) {
        writeTimer.stop()
        d.hasPending = false
        const text = JSON.stringify(value, null, indent) + "\n"
        d.own = d.own.concat([text]).slice(-8)
        d.text = text
        if (d.dirReady)
            file.setText(text)
        else
            mkdir.running = true
    }

    function _read(text) {
        if (d.own.indexOf(text) >= 0)
            return
        let value
        try {
            value = JSON.parse(text)
        } catch (e) {
            console.warn(root.name + " is not valid JSON:", e)
            root.invalid(e)
            return
        }
        root.parsed(value)
    }

    QtObject {
        id: d
        property var own: []
        property var pending: null
        property bool hasPending: false
        property string text: ""
        property bool dirReady: false
    }

    Timer {
        id: writeTimer
        interval: root.writeDelay
        onTriggered: if (d.hasPending) root.write(d.pending)
    }

    FileView {
        id: file
        path: root.path
        blockLoading: true
        watchChanges: root.watch
        atomicWrites: root.atomicWrites
        printErrors: false

        onFileChanged: reload()
        onLoaded: root._read(text())
        onLoadFailed: root.missing()
        Component.onCompleted: if (loaded) root._read(text())
        onSaved: root.saved()
        onSaveFailed: error => {
            console.warn(root.name + " could not be saved:", error)
            root.saveFailed(error)
        }
    }

    Timer {
        running: root.retryInterval > 0 && !file.loaded
        interval: root.retryInterval
        repeat: true
        onTriggered: file.reload()
    }

    // The folder has to exist for the first write.
    Process {
        id: mkdir
        command: ["mkdir", "-p", root.dir]
        onExited: {
            d.dirReady = true
            file.setText(d.text)
        }
    }
}
