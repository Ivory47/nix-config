import QtQuick
import qs.shared

// A tag as a pill: a filter (toggles), a removable tag of the selected wallpaper, or a suggestion.
// Nothing translucent: it sits over the glass (selected = filled, otherwise an outline). The texts are
// CenteredText: centred on the capital letters, so the pill looks right with any font.
Rectangle {
    id: root

    property string text: ""
    // Number of wallpapers with this tag; -1 shows none.
    property int count: -1
    property bool selected: false
    property bool removable: false

    signal clicked()
    signal removed()

    readonly property bool hovered: body.containsMouse || (removable && cross.containsMouse)

    implicitHeight: 26
    implicitWidth: label.implicitWidth + (removable ? 8 + 16 : 0) + 22 + (countText.visible ? countText.implicitWidth + 6 : 0)
    width: implicitWidth
    height: implicitHeight
    radius: height / 2

    color: selected ? Theme.accent : (hovered ? Theme.surface : "transparent")
    border.width: 1
    border.color: selected ? Theme.accent : (hovered ? Theme.textMuted : Theme.surfaceAlt)

    Row {
        anchors.centerIn: parent
        spacing: 6

        CenteredText {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            font.pixelSize: Theme.textSmall
            color: root.selected ? Theme.background : Theme.textSecondary
        }

        CenteredText {
            id: countText
            visible: root.count >= 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.count
            font.pixelSize: Theme.textSmall - 2
            color: root.selected ? Theme.background : Theme.textMuted
        }

        Text {
            visible: root.removable
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            horizontalAlignment: Text.AlignHCenter
            text: "×"
            font.pixelSize: Theme.textMedium + 2
            color: cross.containsMouse ? Theme.red : Theme.textMuted
        }
    }

    MouseArea {
        id: body
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    // On top of the body, over the "×" only.
    MouseArea {
        id: cross
        visible: root.removable
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 28
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.removed()
    }
}
