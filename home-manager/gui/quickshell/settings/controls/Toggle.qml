import QtQuick
import qs.shared

// An on / off switch: a track and a knob (the knob is the height minus 6 px). `checked` is the state;
// a click reports `toggled()` and leaves changing it to the owner. Opaque: it sits over the glass.
Rectangle {
    id: root

    property bool checked: false
    signal toggled()

    width: 42
    height: 22
    radius: height / 2
    color: checked ? Theme.accent : Theme.surface
    border.width: 1
    border.color: Theme.surfaceAlt

    Rectangle {
        x: root.checked ? parent.width - width - 3 : 3
        anchors.verticalCenter: parent.verticalCenter
        width: root.height - 6
        height: width
        radius: width / 2
        color: root.checked ? Theme.background : Theme.textMuted

        Behavior on x { NumberAnimation { duration: 90 } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
