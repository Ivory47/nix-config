import QtQuick
import qs.shared

// The colour section of the detail pane: the colours matugen found (one to pick) and the live preview of the
// scheme that colour would give. `pane` is the DetailPane (its state and signals).
Column {
    id: section

    required property var pane

    width: parent.width
    spacing: 8

    DetailSectionLabel { text: "COLOUR   ·   ALT + 1–5" }

    Row {
        spacing: 8
        height: 38

        Text {
            visible: !pane.colors
            anchors.verticalCenter: parent.verticalCenter
            text: "Reading colours…"
            font.pixelSize: Theme.textSmall
            color: Theme.textMuted
        }

        Repeater {
            model: pane.colors || []

            Rectangle {
                id: ring
                required property string modelData
                required property int index
                readonly property bool chosen: index === pane.colorIndex

                width: 38
                height: 38
                radius: 19
                color: "transparent"
                border.width: 2
                border.color: chosen ? Theme.text : (swatchMouse.containsMouse ? Theme.textMuted : "transparent")

                Rectangle {
                    anchors.centerIn: parent
                    width: 28
                    height: 28
                    radius: 14
                    color: ring.modelData
                }

                MouseArea {
                    id: swatchMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pane.colorPicked(ring.index)
                }
            }
        }
    }

    // What this colour, scheme and mode give.
    Rectangle {
        width: parent.width
        height: 66
        radius: Theme.radiusMedium
        color: pane.roles ? pane.roles.background : Theme.surface
        border.width: 1
        border.color: Theme.surfaceAlt

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 14
            spacing: 14
            visible: !!pane.roles

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Aa"
                font.pixelSize: 26
                font.bold: true
                color: pane.roles ? pane.roles.on_background : Theme.text
            }

            Repeater {
                model: [
                    { label: "Primary", fill: "primary", ink: "on_primary" },
                    { label: "Secondary", fill: "secondary", ink: "on_secondary" },
                    { label: "Tertiary", fill: "tertiary", ink: "on_tertiary" }
                ]

                Rectangle {
                    required property var modelData
                    anchors.verticalCenter: parent.verticalCenter
                    width: pillText.implicitWidth + 16
                    height: 26
                    radius: 13
                    color: pane.roles ? pane.roles[modelData.fill] : "transparent"

                    CenteredText {
                        id: pillText
                        anchors.centerIn: parent
                        text: parent.modelData.label
                        font.pixelSize: Theme.textSmall - 1
                        color: pane.roles ? pane.roles[parent.modelData.ink] : Theme.text
                    }
                }
            }
        }
    }
}
