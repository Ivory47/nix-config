import QtQuick
import QtQuick.Controls
import qs.shared

// One parameter of a window rule's glass: a label and note, a slider with its value (or, for a
// colour, a swatch and a hex field), and a reset arrow when the rule sets it. Not set = the plugin's
// own default (`spec.def`), shown dimmed. It only reports: `preview` while a slider is dragged,
// `commit` when it is released or a valid value was typed, `cleared` for the reset arrow. `readOnly`
// shows the value only (no dragging, typing or reset).
// (The settings rows of the Theme page are tied to ThemeStore; this is the plain version.)
Item {
    id: root

    // { key, label, note, min, max, step, def, type }
    required property var spec
    property var value: undefined      // undefined: not set
    readonly property bool isSet: value !== undefined
    readonly property var shown: isSet ? value : spec.def
    readonly property bool isColor: spec.type === "color"
    property bool readOnly: false

    signal preview(var v)
    signal commit(var v)
    signal cleared()

    width: parent ? parent.width : 0
    height: 44

    SettingsLabel {
        label: root.spec.label
        note: root.spec.note || ""
        labelColor: root.isSet ? Theme.text : Theme.textSecondary
        width: Math.max(0, controls.x - Theme.spacingMedium)
    }

    Item {
        id: controls
        anchors.right: resetButton.left
        anchors.rightMargin: Theme.spacingSmall
        // (The same column as the Theme pages' rows, SettingsRow.controlColumn.)
        width: Math.min(340, root.width * 0.55)
        height: parent.height
        enabled: !root.readOnly

        // A number: slider and value.
        SettingsSlider {
            visible: !root.isColor
            anchors.fill: parent
            from: root.spec.min ?? 0
            to: root.spec.max ?? 1
            step: root.spec.step ?? 0.01
            value: root.isColor ? 0 : root.shown
            decimals: root.spec.step < 0.1 ? 2 : (root.spec.step < 1 ? 1 : 0)
            dimmed: !root.isSet
            onMoved: v => root.preview(v)
            onReleased: v => root.commit(v)
        }

        // A colour: swatch and hex.
        Row {
            visible: root.isColor
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingSmall

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 26
                radius: Theme.radiusSmall
                color: /^#[0-9a-fA-F]{6}$/.test(hex.text) ? hex.text : "transparent"
                border.width: 1
                border.color: Theme.surfaceAlt
            }

            TextField {
                id: hex
                width: 100
                height: 28
                leftPadding: 8
                rightPadding: 8
                topPadding: 0
                bottomPadding: 0
                verticalAlignment: TextInput.AlignVCenter
                selectByMouse: true
                font.family: "monospace"
                font.pixelSize: Theme.textSmall + 1
                color: root.isSet ? Theme.text : Theme.textMuted
                maximumLength: 7
                text: root.isColor ? String(root.shown) : ""

                readonly property bool valid: /^#[0-9a-fA-F]{6}$/.test(text)

                background: Rectangle {
                    radius: Theme.radiusSmall
                    color: "transparent"
                    border.width: 1
                    border.color: !hex.valid ? Theme.red : (hex.activeFocus ? Theme.accent : Theme.surfaceAlt)
                }

                onTextEdited: if (valid) root.commit(text.toLowerCase())
            }
        }
    }

    ResetButton {
        id: resetButton
        active: root.isSet && !root.readOnly
        onClicked: root.cleared()
    }
}
