import QtQuick
import QtQuick.Controls
import qs.shared

// One parameter of a window rule's glass: a label and note, a slider with its value (or, for a
// colour, a swatch and a hex field), and a reset arrow when the rule sets it. Not set = the plugin's
// own default (`spec.def`), shown dimmed. It only reports: `preview` while a slider is dragged,
// `commit` when it is released or a valid value was typed, `cleared` for the reset arrow.
// (The settings rows of the Theme page are tied to ThemeStore; this is the plain version.)
Item {
    id: root

    // { key, label, note, min, max, step, def, type }
    required property var spec
    property var value: undefined      // undefined: not set
    readonly property bool isSet: value !== undefined
    readonly property var shown: isSet ? value : spec.def
    readonly property bool isColor: spec.type === "color"

    signal preview(var v)
    signal commit(var v)
    signal cleared()

    width: parent ? parent.width : 0
    height: 44

    function clamp(v) {
        const s = Math.round(v / spec.step) * spec.step
        return Math.max(spec.min, Math.min(spec.max, Number(s.toFixed(4))))
    }

    function text(v) {
        return v.toFixed(spec.step < 0.1 ? 2 : (spec.step < 1 ? 1 : 0))
    }

    Column {
        anchors.left: parent.left
        width: Math.max(0, controls.x - Theme.spacingMedium)
        y: 22 - height / 2
        spacing: 1

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.spec.label
            color: root.isSet ? Theme.text : Theme.textSecondary
            font.pixelSize: Theme.textMedium
        }

        Text {
            visible: !!root.spec.note
            width: parent.width
            elide: Text.ElideRight
            text: root.spec.note || ""
            color: Theme.textMuted
            font.pixelSize: Theme.textSmall - 1
        }
    }

    Item {
        id: controls
        anchors.right: resetButton.left
        anchors.rightMargin: Theme.spacingSmall
        width: 200
        height: parent.height

        // A number: slider and value.
        Item {
            visible: !root.isColor
            anchors.fill: parent

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
                    color: root.isSet ? Theme.accent : Theme.surfaceAlt
                }

                Rectangle {
                    id: handle
                    width: 14
                    height: 14
                    radius: 7
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.isColor ? 0 : (root.shown - root.spec.min) / (root.spec.max - root.spec.min) * (groove.width - width)
                    color: root.isSet ? Theme.text : Theme.textMuted
                }
            }

            MouseArea {
                x: 0
                width: groove.width
                height: parent.height
                cursorShape: Qt.PointingHandCursor
                // A drag moves the slider; the page's Flickable must not take it over.
                preventStealing: true

                function at(mx) {
                    const f = Math.max(0, Math.min(1, (mx - handle.width / 2) / (groove.width - handle.width)))
                    return root.clamp(root.spec.min + f * (root.spec.max - root.spec.min))
                }

                onPressed: mouse => root.preview(at(mouse.x))
                onPositionChanged: mouse => { if (pressed) root.preview(at(mouse.x)) }
                onReleased: mouse => root.commit(at(mouse.x))
            }

            Text {
                x: 160
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                text: root.isColor ? "" : root.text(root.shown)
                color: root.isSet ? Theme.textSecondary : Theme.textMuted
                font.pixelSize: Theme.textMedium
            }
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

    Item {
        id: resetButton
        anchors.right: parent.right
        y: 11
        width: 22
        height: 22

        Text {
            anchors.centerIn: parent
            visible: root.isSet
            text: "↺"
            color: resetArea.containsMouse ? Theme.text : Theme.textMuted
            font.pixelSize: Theme.textLarge - 4
        }

        MouseArea {
            id: resetArea
            anchors.fill: parent
            enabled: root.isSet
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.cleared()
        }
    }
}
