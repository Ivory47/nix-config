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
    Item {
        id: slider
        visible: !root.isInt
        width: visible ? 200 : 0
        height: 44

        Rectangle {
            id: groove
            x: 0
            y: 20
            width: 150
            height: 4
            radius: 2
            color: Theme.surface
            border.width: 1
            border.color: Theme.surfaceAlt

            Rectangle {
                width: handle.x + handle.width / 2
                height: parent.height
                radius: 2
                color: Theme.accent
            }

            Rectangle {
                id: handle
                width: 14
                height: 14
                radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: (root.value - root.spec.min) / (root.spec.max - root.spec.min) * (groove.width - width)
                color: Theme.text
            }
        }

        MouseArea {
            x: 0
            width: groove.width
            height: parent.height
            cursorShape: Qt.PointingHandCursor
            // A drag moves the slider; the page's Flickable must not take it over.
            preventStealing: true

            function move(mx) {
                const f = Math.max(0, Math.min(1, (mx - handle.width / 2) / (groove.width - handle.width)))
                ThemeStore.preview(root.spec.key, root.clamp(root.spec.min + f * (root.spec.max - root.spec.min)))
            }

            onPressed: mouse => move(mouse.x)
            onPositionChanged: mouse => { if (pressed) move(mouse.x) }
            onReleased: ThemeStore.commit()
        }

        Text {
            x: 160
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            text: root.text(root.value)
            color: Theme.textSecondary
            font.pixelSize: Theme.textMedium
        }
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

                Text {
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
