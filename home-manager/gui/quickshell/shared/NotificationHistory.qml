pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The notification history, read from the file the notification server writes
// (notifications/shell.qml, `history`). `items` is newest first: { seq, app, icon, summary, body,
// urgency (0 low, 1 normal, 2 critical), time (ms), read }. Changes go through the server's IPC.
Singleton {
    id: root

    readonly property string path:
        (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-notifications-history.json"

    property var items: []
    property int unread: 0

    function markRead() {
        if (unread > 0)
            Quickshell.execDetached(["qs", "-c", "notifications", "ipc", "call", "notifications", "markRead"])
    }
    function clear() {
        Quickshell.execDetached(["qs", "-c", "notifications", "ipc", "call", "notifications", "clearHistory"])
    }
    function remove(seq) {
        Quickshell.execDetached(["qs", "-c", "notifications", "ipc", "call", "notifications", "removeFromHistory", String(seq)])
    }

    // "5 min ago" style.
    function ago(ms) {
        const s = Math.max(0, Math.round((Date.now() - ms) / 1000))
        if (s < 60)
            return "now"
        if (s < 3600)
            return Math.round(s / 60) + " min"
        if (s < 86400)
            return Math.round(s / 3600) + " h"
        return Math.round(s / 86400) + " d"
    }

    function parse(text) {
        try {
            const o = JSON.parse(text)
            items = Array.isArray(o.items) ? o.items : []
            unread = typeof o.unread === "number" ? o.unread : 0
        } catch (e) {
            items = []
            unread = 0
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
        onLoadFailed: { root.items = []; root.unread = 0 }
        Component.onCompleted: if (loaded) root.parse(text())
    }

    // A file that does not exist yet is not watched (the server writes it when it starts):
    // look every 3 s until it is there.
    Timer {
        interval: 3000
        running: !file.loaded
        repeat: true
        onTriggered: file.reload()
    }
}
