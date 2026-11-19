import Quickshell
import QtQuick
import qs.shared
import qs.shared.glass

GlassListRow {
    id: root

    required property var app

    width: 420
    height: 64

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
        anchors.right: modePill.visible ? modePill.left : parent.right
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

    // Apps that can be opened as an overlay or as a normal window (LauncherModes): which one. Click
    // it, or press Tab on the selected row. Opaque / outline only, like everything over the glass.
    // (After the row's MouseArea, so it gets the click; no hover of its own, so the row stays hovered.)
    Rectangle {
        id: modePill

        readonly property bool asWindow: LauncherModes.isWindow(root.app)

        visible: LauncherModes.hasChoice(root.app)
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingMedium
        anchors.verticalCenter: parent.verticalCenter
        width: 144
        height: 26
        radius: 13
        color: "transparent"
        border.width: 1
        border.color: Theme.surfaceAlt

        Row {
            anchors.fill: parent

            Repeater {
                model: [ { id: false, label: "Overlay" }, { id: true, label: "Window" } ]

                Rectangle {
                    required property var modelData
                    readonly property bool on: modePill.asWindow === modelData.id

                    width: modePill.width / 2
                    height: modePill.height
                    radius: 13
                    color: on ? Theme.accent : "transparent"

                    CenteredText {
                        anchors.centerIn: parent
                        text: parent.modelData.label
                        font.pixelSize: Theme.textSmall - 1
                        font.bold: parent.on
                        color: parent.on ? Theme.background : Theme.textSecondary
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: LauncherModes.toggle(root.app)
        }
    }
}
