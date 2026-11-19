import QtQuick
import qs.shared

// A whole number (spec.kind "int": minus and plus buttons) or a fraction (kind "real": a slider).
SettingsRow {
    id: root

    readonly property real value: Theme[spec.key]
    readonly property bool isInt: spec.kind === "int"
    readonly property real step: spec.step || (isInt ? 1 : 0.01)

    function clamp(v) {
        const s = Math.round(v / step) * step
        return Math.max(spec.min, Math.min(spec.max, Number(s.toFixed(4))))
    }

    function text(v) {
        return isInt ? String(Math.round(v)) : v.toFixed(step < 0.1 ? 2 : 1)
    }

    // Slider (kind "real")
    SettingsSlider {
        visible: !root.isInt
        width: visible ? 200 : 0
        from: root.spec.min
        to: root.spec.max
        step: root.step
        value: root.value
        decimals: root.step < 0.1 ? 2 : 1
        onMoved: v => ThemeStore.preview(root.spec.key, v)
        onReleased: ThemeStore.commit()
    }

    // Stepper (kind "int")
    Row {
        visible: root.isInt
        width: visible ? implicitWidth : 0
        height: 44
        spacing: Theme.spacingSmall

        Repeater {
            model: [-1, 0, 1]

            delegate: Item {
                id: cell
                required property int modelData
                width: modelData === 0 ? 40 : 26
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
                        onClicked: ThemeStore.set(root.spec.key, root.clamp(root.value + cell.modelData * root.step))
                    }
                }

                CenteredText {
                    visible: cell.modelData === 0
                    anchors.centerIn: parent
                    text: root.text(root.value)
                    color: Theme.textSecondary
                    font.pixelSize: Theme.textMedium
                }
            }
        }
    }
}
