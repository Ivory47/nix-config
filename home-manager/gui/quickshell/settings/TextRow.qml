import QtQuick
import QtQuick.Controls
import qs.shared

// A label on the left and a text field on the right (a rule's name, or one of the things it matches).
// `valid` false outlines the field red. Reports every edit with `edited(text)`.
Item {
    id: root

    property string label: ""
    property string note: ""
    property string placeholder: ""
    property string value: ""
    property bool valid: true

    signal edited(string text)

    width: parent ? parent.width : 0
    height: 44

    Column {
        anchors.left: parent.left
        width: 190
        y: 22 - height / 2
        spacing: 1

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.label
            color: Theme.text
            font.pixelSize: Theme.textMedium
        }

        Text {
            visible: root.note.length > 0
            width: parent.width
            elide: Text.ElideRight
            text: root.note
            color: Theme.textMuted
            font.pixelSize: Theme.textSmall - 1
        }
    }

    TextField {
        id: field
        anchors.left: parent.left
        anchors.leftMargin: 200
        anchors.right: parent.right
        anchors.rightMargin: 22 + Theme.spacingSmall
        anchors.verticalCenter: parent.verticalCenter
        height: 30
        leftPadding: 10
        rightPadding: 10
        topPadding: 0
        bottomPadding: 0
        verticalAlignment: TextInput.AlignVCenter
        selectByMouse: true
        font.family: "monospace"
        font.pixelSize: Theme.textSmall + 1
        color: Theme.text
        placeholderText: root.placeholder
        placeholderTextColor: Theme.textMuted
        text: root.value

        background: Rectangle {
            radius: Theme.radiusSmall
            color: "transparent"
            border.width: field.activeFocus ? 2 : 1
            border.color: !root.valid ? Theme.red : (field.activeFocus ? Theme.accent : Theme.surfaceAlt)
        }

        onTextEdited: root.edited(text)
    }
}
