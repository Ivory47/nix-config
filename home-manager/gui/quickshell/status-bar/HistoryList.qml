import QtQuick
import qs.shared

// The notification history as a list (newest first): app, time, summary, body; a click on the
// cross removes one. A header with "Clear". Opaque children only (it sits over the glass).
Item {
    id: root

    property int maxHeight: 360
    implicitHeight: Math.min(maxHeight, header.height + 8 + (list.contentHeight > 0 ? list.contentHeight : empty.height))
    implicitWidth: 360

    Item {
        id: header
        width: parent.width
        height: 28

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Notifications"
            color: Theme.text
            font.pixelSize: 13
            font.bold: true
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: NotificationHistory.items.length > 0
            text: "Clear"
            color: clearArea.containsMouse ? Theme.text : Theme.textMuted
            font.pixelSize: 12
            MouseArea {
                id: clearArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: NotificationHistory.clear()
            }
        }
    }

    Text {
        id: empty
        visible: NotificationHistory.items.length === 0
        anchors.top: header.bottom
        anchors.topMargin: 8
        text: "Nothing yet"
        color: Theme.textMuted
        font.pixelSize: 12
        height: 24
    }

    ListView {
        id: list
        anchors.top: header.bottom
        anchors.topMargin: 8
        anchors.bottom: parent.bottom
        width: parent.width
        clip: true
        spacing: 8
        model: NotificationHistory.items
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            id: row
            required property var modelData
            width: list.width
            height: col.height

            Column {
                id: col
                width: parent.width - 24
                spacing: 1

                Row {
                    spacing: 8
                    Text {
                        text: row.modelData.app || "Notification"
                        color: row.modelData.urgency === 2 ? Theme.red : Theme.textMuted
                        font.pixelSize: 11
                    }
                    Text {
                        text: NotificationHistory.ago(row.modelData.time)
                        color: Theme.textMuted
                        font.pixelSize: 11
                    }
                }
                Text {
                    width: parent.width
                    text: row.modelData.summary
                    elide: Text.ElideRight
                    color: Theme.text
                    font.pixelSize: 13
                    font.bold: true
                }
                Text {
                    visible: row.modelData.body !== ""
                    width: parent.width
                    text: row.modelData.body
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    color: Theme.textMuted
                    font.pixelSize: 12
                    textFormat: Text.PlainText
                }
            }

            Text {
                anchors.right: parent.right
                anchors.top: parent.top
                text: "󰅖"
                color: rm.containsMouse ? Theme.text : Theme.textMuted
                font.pixelSize: 13
                MouseArea {
                    id: rm
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationHistory.remove(row.modelData.seq)
                }
            }
        }
    }
}
