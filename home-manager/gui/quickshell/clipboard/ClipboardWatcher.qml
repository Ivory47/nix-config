import QtQuick
import Quickshell
import Quickshell.Io

// Records everything that gets copied into cliphist, so the popup has history to show.
Scope {
    component Watcher: Scope {
        id: watcher

        required property string type
        required property string storeCommand

        Process {
            id: process

            running: true

            command: [
                "wl-paste", "--type", watcher.type,
                "--watch", "sh", "-c", watcher.storeCommand
            ]

            // Start again if wl-paste ever exits.
            onExited: restartTimer.start()
        }

        Timer {
            id: restartTimer

            interval: 2000

            onTriggered: process.running = true
        }
    }

    // Text is skipped when a password manager marks it as secret.
    Watcher {
        type: "text"
        storeCommand: "wl-paste --list-types | grep -qx x-kde-passwordManagerHint || cliphist store"
    }

    Watcher {
        type: "image"
        storeCommand: "cliphist store"
    }
}
