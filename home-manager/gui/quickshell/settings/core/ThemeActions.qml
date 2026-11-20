import QtQuick
import Quickshell
import Quickshell.Io

// What the buttons in the header of a settings page do (ThemeSchema category `actions`): `actions` is
// id -> { label, icon, busy, busyText, run() }, shown by ThemePage as ActionButtons.
Scope {
    id: root

    readonly property var actions: ({
        restartBar: { label: "\u21BB Restart bar", busy: root.restarting, busyText: "Restarting\u2026", run: () => root.restartBar() },
        testNotification: { label: "Send test", icon: "play", busy: root.testSent, busyText: "Sent", run: () => root.sendTest() }
    })
    property bool restarting: false
    property bool testSent: false

    // Sends a notification over D-Bus (to whatever notification server is running: ours).
    function sendTest() {
        if (testSent)
            return
        testSent = true
        testTimer.restart()
        testProc.running = true
    }

    Process {
        id: testProc
        // ("--" so that the timeout -1 is not taken for an option)
        command: ["busctl", "--user", "call", "--", "org.freedesktop.Notifications", "/org/freedesktop/Notifications",
            "org.freedesktop.Notifications", "Notify", "susssasa{sv}i", "Settings", "0", "preferences-system",
            "Test notification", "This is how a notification looks with your settings.", "0", "0", "-1"]
    }

    Timer {
        id: testTimer
        interval: 1500
        onTriggered: root.testSent = false
    }

    // Restarts the status bar (some values only apply when it starts). Its process is found by
    // the layer it owns (`pkill -f` would also match this command) and started again detached,
    // so that it outlives this one. If the bar is not running, this just starts it.
    function restartBar() {
        if (restarting)
            return
        restarting = true
        restartTimer.restart()
        restartProc.running = true
    }

    Process {
        id: restartProc
        command: ["sh", "-c",
            "kill $(hyprctl layers | grep 'namespace: statusbar' | sed 's/.*pid: //' | sort -u) 2>/dev/null;"
            + " sleep 0.6; setsid -f qs -c status-bar >/dev/null 2>&1"]
    }

    Timer {
        id: restartTimer
        interval: 3000
        onTriggered: root.restarting = false
    }
}
