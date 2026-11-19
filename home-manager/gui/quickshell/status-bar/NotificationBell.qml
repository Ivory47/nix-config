import QtQuick
import qs.shared

// The bell: dim when there is nothing unread, bright with the number of unread notifications.
// `clicked()` opens the history (the layout decides how).
Item {
    id: root

    signal clicked()

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        spacing: 4
        anchors.verticalCenter: parent.verticalCenter

        Text {
            text: NotificationHistory.unread > 0 ? "󰂚" : "󰂜"
            color: NotificationHistory.unread > 0 ? Theme.text : Theme.textMuted
            font.pixelSize: 14
        }
        Text {
            visible: NotificationHistory.unread > 0
            text: NotificationHistory.unread
            color: Theme.accent
            font.pixelSize: 12
            font.bold: true
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
