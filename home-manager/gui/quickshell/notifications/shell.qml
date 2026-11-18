import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The notification server (org.freedesktop.Notifications) and its popups. This process owns the
// D-Bus name: while it is not running, nothing shows notifications and senders get an error.
// IPC target `notifications`: `dismissAll`, `count`.
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
            popups.add(n)
        }
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
    }
}
