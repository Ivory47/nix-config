import QtQuick
import qs.shared

// The middle of the "balanced" bar: the date and the time, in one of three looks (`style`, from
// Theme.barCentreStyle), and the unread notifications. The date-and-time block is what is centred:
// the unread marker sits next to it or under it and never moves it. One click target (`clicked()`).
//
//   capsule: a soft capsule with date | time; a round accent badge with the number to its right.
//   stacked: the time on top, the date small under it; an accent dot after the time when unread.
//   rule:    date and time on one line, a thin line under them that turns accent when unread.
Item {
    id: root

    property string style: Theme.barCentreStyle
    // The panel is open (lights the block up).
    property bool open: false
    // 0..1: the date goes (the time stays exactly where it is). For the indicator.
    property real dateFade: 0
    signal clicked()

    readonly property int unread: NotificationHistory.unread
    readonly property bool lit: open || area.containsMouse

    implicitWidth: block.implicitWidth
    implicitHeight: block.implicitHeight

    Loader {
        id: block
        anchors.centerIn: parent
        sourceComponent: root.style === "stacked" ? stackedC : root.style === "rule" ? ruleC : capsuleC
        readonly property real implicitWidth: item ? item.width : 0
        readonly property real implicitHeight: item ? item.height : 0
    }

    // ---- capsule --------------------------------------------------------------------------------
    Component {
        id: capsuleC
        Rectangle {
            width: capsuleRow.width + 28
            height: 28
            radius: height / 2
            color: Qt.alpha(Theme.text, root.lit ? 0.14 : 0.08)
            border.width: 1
            border.color: Qt.alpha(Theme.text, 0.12)

            Row {
                id: capsuleRow
                anchors.centerIn: parent
                spacing: 11
                Clock {
                    anchors.verticalCenter: parent.verticalCenter
                    format: "ddd d MMM"
                    font.pixelSize: 13
                    opacity: 1 - root.dateFade
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: 1 - root.dateFade
                    width: 1
                    height: 12
                    color: Qt.alpha(Theme.text, 0.3)
                }
                Clock {
                    anchors.verticalCenter: parent.verticalCenter
                    format: "HH:mm"
                    font.pixelSize: 13
                    font.bold: true
                }
            }
        }
    }

    // ---- stacked --------------------------------------------------------------------------------
    Component {
        id: stackedC
        Item {
            width: Math.max(timeText.width, dateText.width)
            height: 32

            Clock {
                id: timeText
                anchors.horizontalCenter: parent.horizontalCenter
                y: 8 - height / 2
                format: "HH:mm"
                font.pixelSize: 16
                font.bold: true
                color: root.lit ? Theme.accent : Theme.text
            }
            Clock {
                id: dateText
                anchors.horizontalCenter: parent.horizontalCenter
                y: 24 - height / 2
                opacity: 1 - root.dateFade
                format: "ddd d MMM"
                font.pixelSize: 11
                font.letterSpacing: 0.6
                color: Qt.alpha(Theme.text, 0.78)
            }
        }
    }

    // ---- rule -----------------------------------------------------------------------------------
    Component {
        id: ruleC
        Item {
            width: ruleRow.width
            height: 30

            Row {
                id: ruleRow
                y: 9 - height / 2
                spacing: 18
                Clock {
                    anchors.verticalCenter: parent.verticalCenter
                    format: "ddd d MMM"
                    font.pixelSize: 14
                    opacity: 1 - root.dateFade
                }
                Clock {
                    anchors.verticalCenter: parent.verticalCenter
                    format: "HH:mm"
                    font.pixelSize: 14
                    font.bold: true
                }
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 23
                width: root.unread > 0 || root.lit ? parent.width : parent.width * 0.4
                height: root.unread > 0 ? 2 : 1
                radius: 1
                color: root.unread > 0 || root.open ? Theme.accent : Qt.alpha(Theme.text, 0.3)
                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            }
        }
    }

    // ---- the unread marker (capsule: the number; stacked: a dot) ---------------------------------
    Rectangle {
        id: marker
        visible: root.unread > 0 && root.style !== "rule"
        readonly property bool dot: root.style === "stacked"
        x: block.x + block.implicitWidth + (dot ? 7 : 10)
        y: dot ? block.y + 5 : block.y + (block.implicitHeight - height) / 2
        width: dot ? 7 : Math.max(20, markerText.implicitWidth + 12)
        height: dot ? 7 : 20
        radius: height / 2
        color: Theme.accent

        CenteredText {
            id: markerText
            visible: !marker.dot
            anchors.centerIn: parent
            text: root.unread
            color: Theme.background
            font.pixelSize: 11
            font.bold: true
        }
    }

    MouseArea {
        id: area
        x: block.x - 8
        y: block.y - 6
        width: block.implicitWidth + 16 + (marker.visible ? marker.width + 14 : 0)
        height: block.implicitHeight + 12
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
