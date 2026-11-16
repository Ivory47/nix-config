import QtQuick
import Quickshell.Io
import qs.shared

// Opens the settings app (its own Quickshell config, `qs -c settings`).
Item {
    id: root

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    Text {
        id: icon

        anchors.centerIn: parent

        text: "󰒓 "  // cog
        color: area.containsMouse ? Theme.text : Theme.textMuted
        font.pixelSize: 14
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: toggle.running = true
    }

    Process {
        id: toggle
        command: ["qs", "-c", "settings", "ipc", "call", "settings", "toggle"]
    }
}
