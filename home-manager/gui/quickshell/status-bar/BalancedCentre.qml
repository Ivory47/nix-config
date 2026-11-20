import QtQuick
import qs.shared

// The middle of the "balanced" bar: the time on top, the date small under it, and an accent dot after
// the time when there are unread notifications. The date-and-time block is what is centred: the dot
// sits next to it and never moves it. One click target (`clicked()`).
Item {
    id: root

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
        sourceComponent: stackedC
        readonly property real implicitWidth: item ? item.width : 0
        readonly property real implicitHeight: item ? item.height : 0
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

    // ---- the unread marker: a dot -----------------------------------------------------------------
    Rectangle {
        id: marker
        visible: root.unread > 0
        x: block.x + block.implicitWidth + 7
        y: block.y + 5
        width: 7
        height: 7
        radius: 3.5
        color: Theme.accent
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
