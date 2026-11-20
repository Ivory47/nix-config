import QtQuick
import qs.shared
import qs.controls
import qs.core

// A "table" section of ThemeSchema: whole-number settings as a grid, one row per `rows` entry ({ label, keys })
// and one column per `columns` title, each cell a stepper; a reset arrow per row (resets the changed ones of
// that row). A changed value is drawn in the text colour, an unchanged one in the secondary colour.
// `page` is the ThemePage (fields to scroll to). Set `width`.
Column {
    id: root

    required property var page
    required property var section

    readonly property real cellWidth: 120
    readonly property real labelWidth: width - section.columns.length * cellWidth - 22 - Theme.spacingSmall

    function specOf(key) {
        return section.items.find(i => i.key === key)
    }

    // Column titles.
    Row {
        x: root.labelWidth
        height: 30

        Repeater {
            model: root.section.columns

            delegate: Text {
                required property string modelData
                width: root.cellWidth
                height: 30
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignBottom
                text: modelData
                color: Theme.textSecondary
                font.pixelSize: Theme.textSmall
            }
        }
    }

    Repeater {
        model: root.section.rows

        delegate: Item {
            id: row
            required property var modelData
            readonly property bool changed: modelData.keys.some(k => ThemeStore.isSet(k))
            width: root.width
            height: 44

            SettingsLabel {
                label: row.modelData.label
                width: root.labelWidth - Theme.spacingMedium
            }

            Row {
                x: root.labelWidth

                Repeater {
                    model: row.modelData.keys

                    delegate: Item {
                        id: cell
                        required property string modelData
                        readonly property var spec: root.specOf(modelData)
                        readonly property real value: ThemeStore.value(modelData)
                        width: root.cellWidth
                        height: 44

                        function flash() { frame.flash() }
                        Component.onCompleted: root.page.fields[cell.modelData] = cell

                        function step(d) {
                            const s = cell.spec
                            ThemeStore.set(cell.modelData, Math.max(s.min, Math.min(s.max, Math.round(cell.value) + d * (s.step || 1))))
                        }

                        // Keyboard (KeyNav): h / l step (H / L: 5 steps), i types the value, r resets this cell.
                        readonly property bool navStop: true
                        function navAdjust(dir, big) { step(big ? 5 * dir : dir) }
                        function navReset() { ThemeStore.reset(cell.modelData) }
                        function navEdit() { stepper.edit() }

                        FlashFrame {
                            id: frame
                            x: 0
                            y: 4
                            width: parent.width
                            height: parent.height - 8
                        }

                        Stepper {
                            id: stepper
                            anchors.centerIn: parent
                            valueWidth: 34
                            text: String(Math.round(cell.value))
                            textColor: ThemeStore.isSet(cell.modelData) ? Theme.text : Theme.textSecondary
                            onStepped: d => cell.step(d)
                            onTyped: v => {
                                const s = cell.spec
                                ThemeStore.set(cell.modelData, Math.max(s.min, Math.min(s.max, Math.round(v))))
                            }
                        }
                    }
                }
            }

            ResetButton {
                active: row.changed
                onClicked: ThemeStore.resetKeys(row.modelData.keys)
            }
        }
    }
}
