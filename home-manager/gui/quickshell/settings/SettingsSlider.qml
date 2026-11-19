import QtQuick
import qs.shared

// The slider of a number setting: a groove with a handle and the value as text to the right (200 x 44).
// It only reports: `moved(v)` while it is dragged (and on the press), `released(v)` when it is let go; `v`
// is clamped and rounded to `step`. `dimmed` draws it in the muted colours (a value that is not set).
Item {
    id: root

    property real from: 0
    property real to: 1
    property real step: 0.01
    property real value: 0
    property int decimals: 2
    property bool dimmed: false

    signal moved(real v)
    signal released(real v)

    width: 200
    height: 44

    function clamp(v) {
        const s = Math.round(v / step) * step
        return Math.max(from, Math.min(to, Number(s.toFixed(4))))
    }

    function at(mx) {
        const f = Math.max(0, Math.min(1, (mx - handle.width / 2) / (groove.width - handle.width)))
        return clamp(from + f * (to - from))
    }

    Rectangle {
        id: groove
        x: 0
        y: 20
        width: 150
        height: 4
        radius: 2
        color: Theme.surface
        border.width: 1
        border.color: Theme.surfaceAlt

        Rectangle {
            width: handle.x + handle.width / 2
            height: parent.height
            radius: 2
            color: root.dimmed ? Theme.surfaceAlt : Theme.accent
        }

        Rectangle {
            id: handle
            width: 14
            height: 14
            radius: 7
            anchors.verticalCenter: parent.verticalCenter
            x: (root.value - root.from) / (root.to - root.from) * (groove.width - width)
            color: root.dimmed ? Theme.textMuted : Theme.text
        }
    }

    MouseArea {
        x: 0
        width: groove.width
        height: parent.height
        cursorShape: Qt.PointingHandCursor
        // A drag moves the slider; the page's Flickable must not take it over.
        preventStealing: true

        onPressed: mouse => root.moved(root.at(mouse.x))
        onPositionChanged: mouse => { if (pressed) root.moved(root.at(mouse.x)) }
        onReleased: mouse => root.released(root.at(mouse.x))
    }

    Text {
        x: 160
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        text: root.value.toFixed(root.decimals)
        color: root.dimmed ? Theme.textMuted : Theme.textSecondary
        font.pixelSize: Theme.textMedium
    }
}
