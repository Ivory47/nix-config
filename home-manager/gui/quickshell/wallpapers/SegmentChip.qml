import QtQuick
import qs.shared

// One segment of the overlay's dark plates (the list filter at the top, the existing tags offered while a
// tag is typed): it fills the height it is given, no outline, solid in the accent colour when `chosen`,
// lighter while the mouse is over it. A count after the text is optional (-1 shows none).
Rectangle {
    id: root

    property string text: ""
    property int count: -1
    property bool chosen: false

    signal clicked()

    width: row.implicitWidth + 32
    radius: height / 2
    color: chosen ? Theme.accent : (area.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent")

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7

        CenteredText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            font.pixelSize: Theme.textMedium
            font.bold: root.chosen
            color: root.chosen ? Theme.background : "white"
        }

        CenteredText {
            visible: root.count >= 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.count
            font.pixelSize: Theme.textSmall
            color: root.chosen ? Qt.rgba(0, 0, 0, 0.55) : Qt.rgba(1, 1, 1, 0.55)
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
