import QtQuick
import qs.shared

Item {
    id: root

    required property var entry

    signal picked()

    property bool selected: false
    property bool hovered: mouseArea.containsMouse

    height: 56

    Rectangle {
        anchors.fill: parent

        radius: Theme.radiusMedium

        // Always transparent: the highlight is drawn by the glass (see ClipboardPopup.qml). A
        // translucent item over the glass would cost the blur under it.
        color: "transparent"
    }

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

    MouseArea {
        id: mouseArea

        anchors.fill: parent

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: root.picked()
    }
}
