import QtQuick
import qs.shared

// One setting: label (and an optional note) on the left, the control on the right, then a reset
// button that shows when the value was changed in the settings app. `below` is for what opens
// under the row (the colour picker). Nothing here is translucent: the popup is over live glass.
Item {
    id: root

    required property var spec
    default property alias control: controlSlot.data
    property alias below: belowSlot.data
    property real belowHeight: 0

    readonly property bool overridden: ThemeStore.isSet(spec.key)

    width: parent ? parent.width : 0
    height: 44 + belowHeight

    Column {
        anchors.left: parent.left
        y: 22 - height / 2
        spacing: 1

        Text {
            text: root.spec.label
            color: Theme.text
            font.pixelSize: Theme.textMedium
        }

        Text {
            visible: !!root.spec.note
            text: root.spec.note || ""
            color: Theme.textMuted
            font.pixelSize: Theme.textSmall - 1
        }
    }

    Item {
        id: controlSlot
        anchors.right: resetButton.left
        anchors.rightMargin: Theme.spacingSmall
        y: 0
        height: 44
        width: childrenRect.width
    }

    Item {
        id: resetButton
        anchors.right: parent.right
        y: 11
        width: 22
        height: 22

        Text {
            anchors.centerIn: parent
            visible: root.overridden
            text: "↺"
            color: resetArea.containsMouse ? Theme.text : Theme.textMuted
            font.pixelSize: Theme.textLarge - 4
        }

        MouseArea {
            id: resetArea
            anchors.fill: parent
            enabled: root.overridden
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ThemeStore.reset(root.spec.key)
        }
    }

    Item {
        id: belowSlot
        anchors.left: parent.left
        anchors.right: parent.right
        y: 44
        height: root.belowHeight
    }
}
