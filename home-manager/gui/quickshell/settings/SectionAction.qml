import QtQuick
import QtQuick.Shapes
import qs.shared

// The button of a settings section (ThemeSchema `button`) as a row of its own, like a setting: label and note
// on the left, the button where the controls are. Set `action` and `width`.
Item {
    id: actionRow

    // { title, note, label, glyph, icon, busy, busyText, run() } (ThemeActions)
    property var action: null

    visible: !!action
    height: visible ? 44 : 0

    SettingsLabel {
        label: actionRow.action?.title ?? ""
        note: actionRow.action?.note ?? ""
        width: Math.max(0, actionButton.x - Theme.spacingMedium)
    }

    // Right edge where the controls end (the reset arrow's column is to the right).
    Rectangle {
        id: actionButton
        anchors.right: parent.right
        anchors.rightMargin: 22 + Theme.spacingSmall
        anchors.verticalCenter: parent.verticalCenter
        width: buttonRow.width + 24
        height: 28
        radius: Theme.radiusSmall
        color: "transparent"
        border.width: 1
        border.color: !actionRow.action?.busy && buttonArea.containsMouse ? Theme.textMuted : Theme.surfaceAlt
        opacity: actionRow.action?.busy ? 0.6 : 1

        Row {
            id: buttonRow
            anchors.centerIn: parent
            spacing: 6

            // A drawn triangle: the font's one sits low (its box is the line's, not the
            // letters'), this one is centred on the middle of the capital letters.
            Shape {
                visible: actionRow.action?.icon === "play" && !actionRow.action?.busy
                width: 7
                height: 9
                anchors.verticalCenter: parent.verticalCenter
                // The letters' ink centre is ~0.5 px below the box centre, and the optical centre
                // of "Send" (x-height) lower still: centred on the box it read as too high.
                anchors.verticalCenterOffset: 0.75
                ShapePath {
                    fillColor: Theme.textSecondary
                    strokeWidth: -1
                    startX: 0
                    startY: 0
                    PathLine { x: 7; y: 4.5 }
                    PathLine { x: 0; y: 9 }
                }
            }

            CenteredText {
                id: buttonText
                anchors.verticalCenter: parent.verticalCenter
                text: actionRow.action?.busy ? (actionRow.action?.busyText ?? "") : (actionRow.action?.glyph ?? "") + (actionRow.action?.label ?? "")
                color: Theme.textSecondary
                font.pixelSize: Theme.textSmall
            }
        }

        MouseArea {
            id: buttonArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: !actionRow.action?.busy
            cursorShape: Qt.PointingHandCursor
            onClicked: actionRow.action.run()
        }
    }
}
