import QtQuick
import QtQuick.Shapes
import qs.shared

// A small button of the settings app (page headers, the sidebar): outlined, or filled with the accent when
// `primary`. `icon: "play"` draws a triangle before the text; `busy` greys it out and shows `busyText`.
// `active` false dims it and ignores clicks.
Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property bool busy: false
    property string busyText: ""
    property bool primary: false
    property bool active: true

    signal clicked()

    readonly property bool usable: active && !busy

    width: buttonRow.width + 24
    height: 30
    radius: Theme.radiusSmall
    color: primary ? (area.pressed ? Theme.textSecondary : Theme.accent) : "transparent"
    border.width: primary ? 0 : 1
    border.color: usable && area.containsMouse ? Theme.textMuted : Theme.surfaceAlt
    opacity: usable ? 1 : 0.5

    Row {
        id: buttonRow
        anchors.centerIn: parent
        spacing: 6

        // A drawn triangle: the font's one sits low (its box is the line's, not the
        // letters'), this one is centred on the middle of the capital letters.
        Shape {
            visible: root.icon === "play" && !root.busy
            width: 7
            height: 9
            anchors.verticalCenter: parent.verticalCenter
            // The letters' ink centre is ~0.5 px below the box centre, and the optical centre
            // of "Send" (x-height) lower still: centred on the box it read as too high.
            anchors.verticalCenterOffset: 0.75
            ShapePath {
                fillColor: Theme.textSecondary
                strokeWidth: -1
                startX: 0
                startY: 0
                PathLine { x: 7; y: 4.5 }
                PathLine { x: 0; y: 9 }
            }
        }

        CenteredText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.busy ? root.busyText : root.text
            color: root.primary ? Theme.background : Theme.textSecondary
            font.pixelSize: Theme.textSmall
            font.bold: root.primary
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.usable
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
