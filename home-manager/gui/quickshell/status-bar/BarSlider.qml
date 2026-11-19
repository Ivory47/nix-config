import QtQuick
import qs.shared

// A horizontal slider, 0..1: drag or click; `moved(v)` while it is dragged.
Item {
    id: root

    property real value: 0
    signal moved(real v)

    implicitHeight: 22
    implicitWidth: 200

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Theme.surfaceAlt

        Rectangle {
            // To the middle of the knob, which is at the value.
            width: 7 + (root.width - 14) * root.value
            height: parent.height
            radius: 3
            color: Theme.accent
        }
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: (root.width - width) * root.value
        width: 14
        height: 14
        radius: 7
        color: Theme.text
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function at(m) { root.moved(Math.max(0, Math.min(1, m.x / root.width))) }
        onPressed: m => at(m)
        onPositionChanged: m => { if (pressed) at(m) }
    }
}
