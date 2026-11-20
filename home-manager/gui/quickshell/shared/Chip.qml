import QtQuick
import qs.shared

// A small clickable label: a tag pill, one segment of a segmented control, a filter chip. `selected` fills it
// with the accent colour; an optional `count` follows the text, and `removable` adds a "×" (`removed()`).
// The defaults are the themed pill with an outline (nothing translucent: it sits over the glass); the
// palette and the shape are properties, so a variant is a few lines (wallpapers/SegmentChip.qml is the
// unthemed one for the dark plates over the wallpaper pictures, settings/controls/Segmented.qml a row of squarer
// ones). The texts are CenteredText: centred on the capital letters, so any font looks right.
Rectangle {
    id: root

    property string text: ""
    // Number of items behind it (a tag's wallpapers); -1 shows none.
    property int count: -1
    property bool selected: false
    property bool removable: false

    signal clicked()
    signal removed()

    // Shape and size.
    property bool pill: true
    property bool outlined: true
    property real horizontalPadding: 22      // in total, left and right
    property real rowSpacing: 6
    property real fontSize: Theme.textSmall
    property real countFontSize: Theme.textSmall - 2
    property bool boldWhenSelected: false

    // Palette.
    property color selectedFill: Theme.accent
    property color hoverFill: Theme.surface
    property color idleBorder: Theme.surfaceAlt
    property color hoverBorder: Theme.textMuted
    property color textColor: Theme.textSecondary
    property color selectedTextColor: Theme.background
    property color countColor: Theme.textMuted
    property color selectedCountColor: Theme.background

    readonly property bool hovered: body.containsMouse || (removable && cross.containsMouse)

    implicitHeight: 26
    implicitWidth: label.implicitWidth + (removable ? 8 + 16 : 0) + horizontalPadding
                   + (countText.visible ? countText.implicitWidth + rowSpacing : 0)
    width: implicitWidth
    height: implicitHeight
    radius: pill ? height / 2 : Theme.radiusSmall

    color: selected ? selectedFill : (hovered ? hoverFill : "transparent")
    border.width: outlined ? 1 : 0
    border.color: selected ? selectedFill : (hovered ? hoverBorder : idleBorder)

    Row {
        anchors.centerIn: parent
        spacing: root.rowSpacing

        CenteredText {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            font.pixelSize: root.fontSize
            font.bold: root.boldWhenSelected && root.selected
            color: root.selected ? root.selectedTextColor : root.textColor
        }

        CenteredText {
            id: countText
            visible: root.count >= 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.count
            font.pixelSize: root.countFontSize
            color: root.selected ? root.selectedCountColor : root.countColor
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
