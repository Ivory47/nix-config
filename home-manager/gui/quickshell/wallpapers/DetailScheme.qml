import QtQuick
import qs.shared

// The scheme type (stepper) and light / dark of the detail pane. `pane` is the DetailPane.
Column {
    id: section

    required property var pane

    width: parent.width
    spacing: 8

    DetailSectionLabel { text: "SCHEME   ·   ALT + ← →   ·   MODE: ALT + M" }

    Rectangle {
        width: parent.width
        height: 34
        radius: Theme.radiusMedium
        color: "transparent"
        border.width: 1
        border.color: Theme.surfaceAlt

        Repeater {
            model: [-1, 1]
            Item {
                required property int modelData
                x: modelData < 0 ? 0 : parent.width - width
                width: 36
                height: parent.height
                Text {
                    anchors.centerIn: parent
                    text: parent.modelData < 0 ? "‹" : "›"
                    font.pixelSize: Theme.textLarge
                    color: stepMouse.containsMouse ? Theme.text : Theme.textSecondary
                }
                MouseArea {
                    id: stepMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pane.schemeStepped(parent.modelData)
                }
            }
        }

        CenteredText {
            anchors.centerIn: parent
            text: pane.schemeNames[pane.schemeType] || pane.schemeType
            font.pixelSize: Theme.textMedium
            color: Theme.text
        }
    }

    Row {
        id: modeRow
        width: parent.width
        spacing: 0
        height: 34

        Repeater {
            model: [ { id: "dark", label: "Dark" }, { id: "light", label: "Light" } ]

            Rectangle {
                required property var modelData
                required property int index
                readonly property bool on: pane.mode === modelData.id

                width: modeRow.width / 2
                height: modeRow.height
                radius: Theme.radiusMedium
                color: on ? Theme.accent : "transparent"
                border.width: 1
                border.color: on ? Theme.accent : Theme.surfaceAlt

                CenteredText {
                    anchors.centerIn: parent
                    text: parent.modelData.label
                    font.pixelSize: Theme.textMedium
                    font.bold: parent.on
                    color: parent.on ? Theme.background : Theme.textSecondary
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pane.modeSet(parent.modelData.id)
                }
            }
        }
    }
}
