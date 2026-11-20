import QtQuick
import qs.shared

// The top of a settings page, above its scrolling part: title, a line that says what is on the page, and
// the page's buttons on the right (put them inside; they go into a Row). A line under it. Set `width`.
Item {
    id: root

    property string title: ""
    property string description: ""
    default property alias buttons: buttonRow.data

    implicitHeight: Math.max(texts.implicitHeight, buttonRow.height) + Theme.spacingMedium + 1

    Column {
        id: texts
        anchors.left: parent.left
        anchors.right: buttonRow.left
        anchors.rightMargin: Theme.spacingLarge
        // (Same inset as the page's rows: SettingsPage's column starts 6 px in.)
        anchors.leftMargin: 6
        spacing: 2

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.title
            color: Theme.text
            font.pixelSize: Theme.textLarge
            font.bold: true
        }

        Text {
            visible: text.length > 0
            width: parent.width
            wrapMode: Text.WordWrap
            text: root.description
            color: Theme.textSecondary
            font.pixelSize: Theme.textSmall
        }
    }

    Row {
        id: buttonRow
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: texts.verticalCenter
        spacing: Theme.spacingSmall
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Theme.surfaceAlt
    }
}
