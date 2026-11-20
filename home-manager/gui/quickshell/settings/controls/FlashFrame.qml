import QtQuick
import qs.shared

// A soft accent area over its parent that shows for a moment and fades out (`flash()`), so that a
// setting can be found after a jump or an undo. Put one inside the item to mark: it takes the parent's
// shape (4 px wider, 2 px less tall; set x, y, width, height for another fit). It takes no mouse.
Rectangle {
    id: root

    // How strong the area is at its peak (0 to 1).
    property real peak: 0.22

    function flash() {
        anim.restart()
    }

    x: -4
    y: 2
    width: parent.width + 8
    height: parent.height - 4
    radius: Theme.radiusMedium
    color: Theme.accent
    opacity: 0
    visible: opacity > 0

    SequentialAnimation {
        id: anim
        NumberAnimation { target: root; property: "opacity"; to: root.peak; duration: 150; easing.type: Easing.OutQuad }
        PauseAnimation { duration: 200 }
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: 400; easing.type: Easing.InOutQuad }
    }
}
