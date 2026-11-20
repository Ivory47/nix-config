import QtQuick
import qs.shared

// An accent outline around its parent that shows for a moment (`flash()`), so that a setting can be
// found after a jump or an undo. On or off, not faded: nothing translucent over the glass. Put one
// inside the item to outline (it is as big as the parent, 4 px wider) and call `flash()`.
Rectangle {
    id: root

    function flash() {
        visible = true
        timer.restart()
    }

    visible: false
    x: -4
    y: 2
    width: parent.width + 8
    height: parent.height - 4
    radius: Theme.radiusMedium
    color: "transparent"
    border.width: 2
    border.color: Theme.accent

    Timer {
        id: timer
        interval: 1400
        onTriggered: root.visible = false
    }
}
