import QtQuick
import qs.shared

// Minus, the value, plus (44 high). Reports a click with `stepped(-1 | 1)`; the owner changes the value. A
// click on the value (or `edit()`) types one, reported with `typed(v)`.
Row {
    id: root

    property string text: ""
    property color textColor: Theme.textSecondary
    property real valueWidth: 40

    signal stepped(int direction)
    // A value typed over the text (a click on it, or `edit()`); the owner clamps it.
    signal typed(real v)

    property Item valueText: null
    function edit() {
        if (valueText)
            valueText.edit()
    }

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

            ValueText {
                id: valueText
                visible: cell.modelData === 0
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.text
                color: root.textColor
                onSubmitted: v => root.typed(v)
                Component.onCompleted: if (cell.modelData === 0) root.valueText = valueText
            }
        }
    }
}
