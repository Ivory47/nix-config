import QtQuick
import qs.shared

// A row of options, one chosen: `options` is [{ id, label }], `current` the chosen id. Opaque or
// outline only (it sits over the glass). Reports a click with `picked(id)`.
Item {
    id: root

    property var options: []
    property var current: ""
    property int segmentHeight: 30

    signal picked(var id)

    implicitWidth: row.implicitWidth
    implicitHeight: segmentHeight
    height: segmentHeight

    Row {
        id: row
        spacing: 0

        Repeater {
            model: root.options

            delegate: Rectangle {
                id: seg
                required property var modelData
                readonly property bool on: root.current === modelData.id

                width: label.implicitWidth + 28
                height: root.segmentHeight
                radius: Theme.radiusSmall
                color: on ? Theme.accent : "transparent"
                border.width: 1
                border.color: on ? Theme.accent : (area.containsMouse ? Theme.textMuted : Theme.surfaceAlt)

                CenteredText {
                    id: label
                    anchors.centerIn: parent
                    text: seg.modelData.label
                    font.pixelSize: Theme.textSmall + 1
                    font.bold: seg.on
                    color: seg.on ? Theme.background : Theme.textSecondary
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(seg.modelData.id)
                }
            }
        }
    }
}
