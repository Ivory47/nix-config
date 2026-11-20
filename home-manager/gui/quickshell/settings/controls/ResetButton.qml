import QtQuick
import qs.shared

// The reset arrow at the right end of a settings row: shown (and clickable) only while `active`, that is,
// while the value was changed from its default. `clicked()` resets it.
Item {
    id: root

    property bool active: false
    signal clicked()

    anchors.right: parent.right
    y: 11
    width: 22
    height: 22

    Text {
        anchors.centerIn: parent
        visible: root.active
        text: "↺"
        color: area.containsMouse ? Theme.text : Theme.textMuted
        font.pixelSize: Theme.textLarge - 4
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.active
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
