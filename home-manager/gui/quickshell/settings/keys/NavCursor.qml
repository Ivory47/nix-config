import QtQuick
import qs.shared
import qs.core

// The keyboard cursor of the settings app (KeyNav). It becomes a child of that item (`target`), so it
// scrolls and is clipped with it; null hides it. Its frame: the target's `navFrame` if it has one (the
// same as an outline it draws itself: a colour cell, a sidebar row in a clipping list), else a row (40 px
// or more) like FlashFrame marks it (4 px wider, 2 px less tall), a smaller item 3 px outside its edges.
// AppSettings.cursor picks how
// the frame is drawn:
//   bar       a short accent line at the left of a row, under a smaller item
//   hairline  a 1 px outline in the muted text colour
//   corners   short accent marks at the four corners
//   outline   a 2 px accent outline
// Lines and outlines only: nothing translucent over the glass. It takes no mouse.
Item {
    id: root

    property Item target: null
    readonly property real targetHeight: !target ? 0
        : target.navHeight !== undefined ? target.navHeight : target.height
    readonly property var frame: target && target.navFrame ? target.navFrame : null
    readonly property bool row: frame ? frame.height >= 40 : targetHeight >= 40
    readonly property string style: AppSettings.cursor
    readonly property real radius: frame ? frame.radius : row ? Theme.radiusMedium : Theme.radiusSmall + 2

    parent: target
    visible: target !== null
    z: 9999
    x: frame ? frame.x : row ? -4 : -3
    y: frame ? frame.y : row ? 2 : -3
    width: frame ? frame.width : target ? target.width + (row ? 8 : 6) : 0
    height: frame ? frame.height : row ? targetHeight - 4 : targetHeight + 6

    // outline, hairline
    Rectangle {
        visible: root.style === "outline" || root.style === "hairline"
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: root.style === "outline" ? 2 : 1
        border.color: root.style === "outline" ? Theme.accent : Theme.textMuted
    }

    // bar: at the left of a row (in the row's outer 4 px), under a smaller item.
    Rectangle {
        visible: root.style === "bar"
        x: root.row ? (root.frame ? 5 : 0) : 3
        y: root.row ? (parent.height - height) / 2 : parent.height - 2
        width: root.row ? 3 : parent.width - 6
        height: root.row ? Math.min(22, parent.height - 12) : 2
        radius: 1.5
        color: Theme.accent
    }

    // corners
    Repeater {
        model: root.style === "corners" ? 4 : 0

        delegate: Item {
            id: corner
            required property int index
            readonly property bool atRight: index % 2 === 1
            readonly property bool atBottom: index > 1
            readonly property real arm: root.row ? 10 : 6
            x: atRight ? root.width - arm : 0
            y: atBottom ? root.height - arm : 0
            width: arm
            height: arm

            Rectangle {
                x: 0
                y: corner.atBottom ? corner.arm - 2 : 0
                width: corner.arm
                height: 2
                radius: 1
                color: Theme.accent
            }
            Rectangle {
                x: corner.atRight ? corner.arm - 2 : 0
                y: 0
                width: 2
                height: corner.arm
                radius: 1
                color: Theme.accent
            }
        }
    }
}
