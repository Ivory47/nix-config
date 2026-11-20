import QtQuick
import qs.shared
import qs.core

// The value of a slider or stepper as text that can be typed over: a click (or `edit()`, KeyNav's i)
// turns it into a field with the text selected. Enter or a click elsewhere reports the number with
// `submitted(v)` (the owner clamps and rounds it; text that is not a number is dropped), Esc keeps the
// old value. Outline only while typing. As wide as `width`, as tall as its parent row.
Item {
    id: root

    property string text: ""
    property color color: Theme.textSecondary
    property int horizontalAlignment: Text.AlignLeft
    readonly property bool editing: input.activeFocus

    signal submitted(real v)

    implicitHeight: 26
    height: implicitHeight

    function edit() {
        input.text = root.text
        input.forceActiveFocus()
        input.selectAll()
    }

    property bool cancelled: false

    // Back to the view that owns the keys (SettingsView.takeFocus), so the vim keys work again.
    function leave() {
        let p = root.parent
        while (p && typeof p.takeFocus !== "function")
            p = p.parent
        if (p)
            p.takeFocus()
        else
            input.focus = false
    }

    Rectangle {
        visible: root.editing
        anchors.fill: parent
        anchors.leftMargin: -4
        anchors.rightMargin: -4
        radius: Theme.radiusSmall
        color: "transparent"
        border.width: 1
        border.color: Theme.accent
    }

    CenteredText {
        visible: !root.editing
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        horizontalAlignment: root.horizontalAlignment
        text: root.text
        color: root.color
        font.pixelSize: Theme.textMedium
    }

    TextInput {
        id: input
        visible: root.editing
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        horizontalAlignment: root.horizontalAlignment
        color: Theme.text
        selectionColor: Theme.accent
        selectedTextColor: Theme.background
        font.pixelSize: Theme.textMedium
        selectByMouse: true
        clip: true
        validator: RegularExpressionValidator { regularExpression: /-?[0-9]*[.,]?[0-9]*/ }

        onActiveFocusChanged: {
            if (activeFocus) {
                root.cancelled = false
                return
            }
            const v = Number(text.replace(",", "."))
            if (!root.cancelled && text.length > 0 && isFinite(v))
                root.submitted(v)
        }

        // The vim keys for leaving a field first (FieldKeys): they keep the old value, like Esc.
        function navCancel() { root.cancelled = true }
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: event => {
            FieldKeys.press(event, input)
            if (event.accepted)
                return
            if (event.key === Qt.Key_Escape) {
                root.cancelled = true
                root.leave()
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.leave()
                event.accepted = true
            }
        }
    }

    MouseArea {
        visible: !root.editing
        anchors.fill: parent
        anchors.leftMargin: -4
        anchors.rightMargin: -4
        cursorShape: Qt.IBeamCursor
        onClicked: root.edit()
    }
}
