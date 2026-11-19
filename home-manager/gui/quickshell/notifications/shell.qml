import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The notification server (org.freedesktop.Notifications) and its popups. This process owns the
// D-Bus name: while it is not running, nothing shows notifications and senders get an error.
// IPC target `notifications`: `dismissAll`, `count`, `markRead`, `clearHistory`, `removeFromHistory`.
ShellRoot {
    NotificationServer {
        id: server
        // Notifications do not outlive the shell (the cards are not kept either).
        keepOnReload: false
        persistenceSupported: false
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true

        onNotification: n => {
            n.tracked = true
            history.record(n)
            popups.add(n)
        }
    }

    // The history: the last `limit` notifications, newest first, written to a file in the runtime
    // directory (atomic replace) that the status bar reads (shared/NotificationHistory.qml). Kept in
    // memory only: gone when this shell restarts. The sender has forgotten them, so no actions.
    QtObject {
        id: history

        readonly property int limit: 50
        property var items: []
        property int nextSeq: 1

        readonly property string path:
            (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-notifications-history.json"

        function record(n) {
            const e = {
                seq: nextSeq++,
                app: n.appName,
                icon: n.appIcon,
                summary: n.summary,
                body: n.body,
                urgency: n.urgency === NotificationUrgency.Critical ? 2 : n.urgency === NotificationUrgency.Low ? 0 : 1,
                time: Date.now(),
                read: false
            }
            items = [e].concat(items).slice(0, limit)
            save()
        }

        function markRead() {
            items = items.map(e => Object.assign({}, e, { read: true }))
            save()
        }

        function clear() {
            items = []
            save()
        }

        function remove(seq) {
            items = items.filter(e => e.seq !== seq)
            save()
        }

        function save() {
            file.setText(JSON.stringify({
                unread: items.filter(e => !e.read).length,
                items: items
            }))
        }

        property var file: FileView {
            path: history.path
            atomicWrites: true
            printErrors: false
        }

        Component.onCompleted: save()
    }

    NotificationPopups {
        id: popups
    }

    IpcHandler {
        target: "notifications"

        function dismissAll(): void {
            popups.dismissAll()
        }

        function count(): int {
            return popups.count
        }

        function markRead(): void {
            history.markRead()
        }

        function clearHistory(): void {
            history.clear()
        }

        function removeFromHistory(seq: int): void {
            history.remove(seq)
        }
    }
}
