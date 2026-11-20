import QtQuick
import qs.shared

// A "colors" section of ThemeSchema: each block is a titled grid of cells (swatch, name, hex, reset arrow);
// a click on a cell opens the full colour row (hex field, picker) under that block, a second click (or one
// on its swatch) closes it. Which colour is open is ThemeStore.openColor (one at a time in the whole app).
// `page` is the ThemePage (fields to scroll to). Set `width`.
Column {
    id: root

    required property var page
    required property var section

    Repeater {
        model: root.section.blocks

        delegate: Column {
            id: block
            required property var modelData
            width: root.width

            readonly property var openSpec: modelData.items.find(i => i.key === ThemeStore.openColor) ?? null

            BlockTitle {
                text: block.modelData.title
            }

            Grid {
                id: grid
                width: parent.width
                columns: Math.max(2, Math.floor(width / 200))
                columnSpacing: Theme.spacingSmall
                rowSpacing: 0
                readonly property real cellWidth: (width - (columns - 1) * columnSpacing) / columns

                Repeater {
                    model: block.modelData.items

                    delegate: Item {
                        id: cell
                        required property var modelData
                        readonly property color value: Theme[modelData.key]
                        readonly property bool open: ThemeStore.openColor === modelData.key

                        width: grid.cellWidth
                        height: 48

                        property bool flashing: false
                        function flash() {
                            flashing = true
                            flashTimer.restart()
                        }
                        Timer {
                            id: flashTimer
                            interval: 1400
                            onTriggered: cell.flashing = false
                        }

                        Component.onCompleted: root.page.fields[cell.modelData.key] = cell

                        // Hover fill, open (or found) outline. Opaque or outline only: over the glass.
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: Theme.radiusMedium
                            color: cellArea.containsMouse ? Theme.surface : "transparent"
                            border.width: cell.open || cell.flashing ? (cell.flashing ? 2 : 1) : 0
                            border.color: cell.flashing ? Theme.accent : Theme.textMuted
                        }

                        Rectangle {
                            id: swatch
                            x: Theme.spacingMedium
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30
                            height: 22
                            radius: Theme.radiusSmall
                            // Opaque version of the colour; transparency shows in the editor's alpha bar.
                            color: Qt.rgba(cell.value.r, cell.value.g, cell.value.b, 1)
                            border.width: 1
                            border.color: Theme.surfaceAlt
                        }

                        Column {
                            anchors.left: swatch.right
                            anchors.leftMargin: Theme.spacingMedium
                            anchors.right: reset.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: cell.modelData.label
                                color: Theme.text
                                font.pixelSize: Theme.textMedium
                            }
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: ThemeStore.colorString(cell.value, !!cell.modelData.alpha)
                                color: Theme.textMuted
                                font.pixelSize: Theme.textSmall - 1
                                font.family: "monospace"
                            }
                        }

                        MouseArea {
                            id: cellArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ThemeStore.openColor = cell.open ? "" : cell.modelData.key
                        }

                        // (Over the cell's MouseArea, so that it takes its own clicks.)
                        ResetButton {
                            id: reset
                            y: 13
                            anchors.rightMargin: Theme.spacingSmall
                            active: ThemeStore.isSet(cell.modelData.key)
                            onClicked: ThemeStore.reset(cell.modelData.key)
                        }
                    }
                }
            }

            // The open colour of this block: its full row, with the picker.
            Loader {
                width: parent.width
                active: block.openSpec !== null
                visible: active
                sourceComponent: ColorField {
                    spec: block.openSpec
                }
            }
        }
    }
}
