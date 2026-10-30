import QtQuick
import Quickshell
import Quickshell.Io

// Reads clipboard history from cliphist and copies entries back to the clipboard.
Scope {
    id: root

    signal copied()

    property var entries: []
    property string searchText: ""

    property var filteredEntries: {
        const query = searchText.trim().toLowerCase()

        if (query === "")
            return entries

        return entries.filter(entry => entry.preview.toLowerCase().includes(query))
    }

    function refresh() {
        listProcess.running = true
    }

    function copy(entry) {
        if (!entry)
            return

        copyProcess.command = [
            "sh", "-c",
            'cliphist decode "$1" | wl-copy >/dev/null 2>&1',
            "sh", entry.id
        ]
        copyProcess.running = true
    }

    function remove(entry) {
        if (!entry)
            return

        // Update the list right away, then delete in cliphist.
        entries = entries.filter(e => e.id !== entry.id)

        deleteProcess.command = [
            "sh", "-c",
            'printf "%s\\t\\n" "$1" | cliphist delete',
            "sh", entry.id
        ]
        deleteProcess.running = true
    }

    // cliphist list prints "<id>\t<preview>" per line.
    // Images and other binary data show up as "[[ binary data 12 KiB png 800x600 ]]".
    function parse(raw) {
        const result = []
        const lines = raw.split("\n")

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i]
            const tab = line.indexOf("\t")

            if (tab < 1)
                continue

            const preview = line.slice(tab + 1)
            const binary = preview.startsWith("[[ binary data")

            result.push({
                id: line.slice(0, tab),
                preview: preview,
                isBinary: binary,
                meta: binary
                    ? preview.replace("[[ binary data ", "").replace(" ]]", "")
                    : ""
            })
        }

        return result
    }

    Process {
        id: listProcess

        command: ["cliphist", "list"]

        stdout: StdioCollector {
            onStreamFinished: root.entries = root.parse(text)
        }
    }

    Process {
        id: copyProcess

        onExited: root.copied()
    }

    Process {
        id: deleteProcess
    }
}
