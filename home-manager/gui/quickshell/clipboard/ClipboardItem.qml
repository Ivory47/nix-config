import QtQuick
import qs.shared
import qs.shared.glass

GlassListRow {
    id: root

    required property var entry

    height: 56

    Column {
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingMedium
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingMedium
        anchors.verticalCenter: parent.verticalCenter

        spacing: 2

        Text {
            width: parent.width

            text: root.entry.isBinary ? "Image / binary data" : root.entry.preview
            color: Theme.text
            font.pixelSize: Theme.textMedium

            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            maximumLineCount: root.entry.isBinary ? 1 : 2
            elide: Text.ElideRight
        }

        Text {
            width: parent.width

            text: root.entry.meta
            color: Theme.textSecondary
            font.pixelSize: Theme.textSmall

            elide: Text.ElideRight

            visible: text.length > 0
        }
    }
}
