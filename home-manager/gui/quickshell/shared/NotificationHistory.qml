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

    // The server (notifications/shell.qml) writes the file; every process reads it. (Looked for every 3 s
    // until it is there.)
    JsonFile {
        id: file
        path: root.path
        name: "notification history"
        retryInterval: 3000
        onParsed: o => {
            root.items = Array.isArray(o.items) ? o.items : []
            root.unread = typeof o.unread === "number" ? o.unread : 0
        }
        onMissing: { root.items = []; root.unread = 0 }
        onInvalid: { root.items = []; root.unread = 0 }
    }
}
