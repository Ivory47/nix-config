import QtQuick
import qs.shared

// Minus, the value, plus (44 high). Reports a click with `stepped(-1 | 1)`; the owner changes the value.
Row {
    id: root

    property string text: ""
    property color textColor: Theme.textSecondary
    property real valueWidth: 40

    signal stepped(int direction)

    height: 44
    spacing: Theme.spacingSmall

    Repeater {
        model: [-1, 0, 1]

        delegate: Item {
            id: cell
            required property int modelData
            width: modelData === 0 ? root.valueWidth : 26
            height: 44

            Rectangle {
                visible: cell.modelData !== 0
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                height: 26
                radius: Theme.radiusSmall
                color: "transparent"
                border.width: 1
                border.color: stepArea.containsMouse ? Theme.textMuted : Theme.surfaceAlt

                Text {
                    anchors.centerIn: parent
                    text: cell.modelData < 0 ? "−" : "+"
                    color: Theme.text
                    font.pixelSize: Theme.textMedium
                }

                MouseArea {
                    id: stepArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.stepped(cell.modelData)
                }
            }

            CenteredText {
                visible: cell.modelData === 0
                anchors.centerIn: parent
                text: root.text
                color: root.textColor
                font.pixelSize: Theme.textMedium
            }
        }
    }
}
