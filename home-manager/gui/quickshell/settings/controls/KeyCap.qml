import QtQuick
import qs.shared

// One key as a small keyboard cap ("Ctrl+d", "gg"), for the Keyboard page. `removable` adds a "×" that
// reports `removed()`; `muted` draws it quieter (the "+3" of keys not shown); `warn` outlines it orange
// (the key also does something else). Long keys are cut off at `maxTextWidth`. Outline only: it sits
// over the glass.
Rectangle {
    id: root

    property string text: ""
    property bool removable: false
    property bool muted: false
    property bool warn: false
    property real maxTextWidth: 110

    signal removed()

    implicitWidth: row.width + 16
    implicitHeight: 24
    width: implicitWidth
    height: implicitHeight
    radius: Theme.radiusSmall
    color: "transparent"
    border.width: 1
    border.color: warn ? Theme.orange : xArea.containsMouse ? Theme.textMuted : Theme.surfaceAlt

    Row {
        id: row
        x: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        CenteredText {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.maxTextWidth)
            text: root.text
            elide: Text.ElideRight
            color: root.muted ? Theme.textMuted : Theme.text
            font.family: "monospace"
            font.pixelSize: Theme.textSmall + 1
        }

        Text {
            visible: root.removable
            anchors.verticalCenter: parent.verticalCenter
            text: "×"
            color: xArea.containsMouse ? Theme.red : Theme.textMuted
            font.pixelSize: Theme.textMedium

            MouseArea {
                id: xArea
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.removed()
            }
        }
    }
}
