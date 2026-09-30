import Quickshell
import QtQuick

Item {
    id: root

    required property var app

    signal launched()

    property bool selected: false
    property bool hovered: mouseArea.containsMouse

    width: 420
    height: 64

    Rectangle {
        anchors.fill: parent

        radius: Theme.radiusMedium

        color: root.selected || root.hovered
            ? Theme.surface
            : Theme.background

        Behavior on color {
            ColorAnimation {
                duration: 100
            }
        }
    }

    Image {
        id: icon

        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingMedium
        anchors.verticalCenter: parent.verticalCenter

        width: 40
        height: 40

        source: Quickshell.iconPath(root.app.icon)

        sourceSize.width: 40
        sourceSize.height: 40

        fillMode: Image.PreserveAspectFit
        asynchronous: true

        onStatusChanged: {
            if (status === Image.Error)
            source = Qt.resolvedUrl("fallback.svg")
        }
    }

    Column {
        anchors.left: icon.right
        anchors.leftMargin: Theme.spacingMedium
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingMedium
        anchors.verticalCenter: parent.verticalCenter

        spacing: 2

        Text {
            width: parent.width

            text: root.app.name
            color: Theme.text
            font.pixelSize: Theme.textMedium

            elide: Text.ElideRight
        }

        Text {
            width: parent.width

            text: root.app.genericName || ""
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

        onClicked: {
            root.app.execute()
            root.launched()
        }
    }
}
