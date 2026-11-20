import QtQuick
import qs.shared

// The label and the small grey note of a settings row, vertically centred in a 44 px row, on the left.
// Set `width`: the text is cut off with an ellipsis before it gets there (keep it clear of the controls).
// With `wrap` the note wraps instead (up to three lines; the row has to grow with it: SettingsRow does).
Column {
    id: root

    property string label: ""
    property string note: ""
    property color labelColor: Theme.text
    property bool wrap: false

    anchors.left: parent.left
    y: 22 - height / 2
    spacing: 1

    Text {
        width: parent.width
        elide: Text.ElideRight
        text: root.label
        color: root.labelColor
        font.pixelSize: Theme.textMedium
    }

    Text {
        visible: root.note.length > 0
        width: parent.width
        elide: Text.ElideRight
        wrapMode: root.wrap ? Text.WordWrap : Text.NoWrap
        maximumLineCount: root.wrap ? 3 : 1
        text: root.note
        color: Theme.textMuted
        font.pixelSize: Theme.textSmall - 1
    }
}
