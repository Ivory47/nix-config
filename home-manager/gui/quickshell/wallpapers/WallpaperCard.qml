import QtQuick
import Quickshell.Widgets
import qs.shared

// One cell of the wallpaper grid: the thumbnail, the file name under it, the wallpaper's colours as
// dots, and a badge on the one that is on the screen now. The cell's background is transparent: the
// glass draws the selected / hovered highlight (a translucent item over the glass would cost the blur).
Item {
    id: root

    required property var modelData
    required property int index
    readonly property var entry: modelData
    property bool selected: false
    property bool isCurrent: false
    property var colors: undefined
    // Pixels the thumbnail is decoded at (the cell size times the screen's scale).
    property real decodeWidth: 400

    readonly property bool hovered: mouseArea.containsMouse

    signal activated()   // clicked
    signal applied()     // double-clicked

    readonly property int pad: 8

    ClippingRectangle {
        id: frame
        x: root.pad
        y: root.pad
        width: root.width - 2 * root.pad
        height: width * 0.56
        radius: Theme.radiusMedium
        color: Theme.surface

        Image {
            anchors.fill: parent
            source: "file://" + root.entry.path
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: Math.ceil(root.decodeWidth)
            // A fade in once decoded would be translucent over glass: show it as it comes.
        }

        // Colour dots, bottom left, on a solid dark plate so that they read on any picture.
        Rectangle {
            visible: !!root.colors && root.colors.length > 0
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 6
            width: dots.width + 12
            height: 20
            radius: 10
            color: "#262626"

            Row {
                id: dots
                anchors.centerIn: parent
                spacing: 4
                Repeater {
                    model: root.colors || []
                    Rectangle {
                        required property string modelData
                        width: 10
                        height: 10
                        radius: 5
                        color: modelData
                    }
                }
            }
        }

        // "On the screen now".
        Rectangle {
            visible: root.isCurrent
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 6
            width: nowLabel.implicitWidth + 16
            height: 20
            radius: 10
            color: Theme.accent

            Text {
                id: nowLabel
                anchors.centerIn: parent
                text: "✓ Current"
                font.pixelSize: Theme.textSmall - 2
                font.bold: true
                color: Theme.background
            }
        }
    }

    Text {
        anchors.left: frame.left
        anchors.right: frame.right
        anchors.top: frame.bottom
        anchors.topMargin: 6
        text: root.entry.base
        elide: Text.ElideMiddle
        font.pixelSize: Theme.textMedium
        color: Theme.text
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
        onDoubleClicked: root.applied()
    }
}
