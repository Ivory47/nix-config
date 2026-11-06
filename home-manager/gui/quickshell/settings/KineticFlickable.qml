import QtQuick

// A Flickable that keeps gliding after a two-finger touchpad scroll, like Firefox: when the
// fingers leave the pad the page goes on with the speed it had and slows down smoothly, instead
// of stopping dead. (Qt's own Flickable scrolls exactly by the touchpad's deltas, and Wayland
// sends no momentum of its own.) A new touch on the pad stops the glide at once.
//
// Only touchpad events are handled here (they carry a pixelDelta); a mouse wheel is left to the
// Flickable, so it behaves as before. Dragging with the mouse works as before too.
Flickable {
    id: root

    // The glide: the speed falls to 1/e of itself in `glideTime` seconds. Below `minGlideSpeed`
    // (px/s) when the fingers leave, there is no glide.
    property real glideTime: 0.35
    property real minGlideSpeed: 150
    property real maxGlideSpeed: 8000

    boundsBehavior: Flickable.StopAtBounds

    // Scroll speed of the glide, px/s (positive = down the page), and the touchpad events of the
    // last moments ({t, dy}), from which the speed is taken when the fingers leave.
    property real _speed: 0
    property var _samples: []

    function _clamp(y) {
        return Math.max(originY, Math.min(originY + Math.max(0, contentHeight - height), y))
    }

    // One step of a touchpad scroll: the content moves by dy (positive = down the page).
    function scrollBy(dy) {
        glide.running = false
        _speed = 0
        cancelFlick()
        contentY = _clamp(contentY + dy)

        const now = Date.now()
        const keep = _samples.filter(s => now - s.t <= 120)
        keep.push({ t: now, dy: dy })
        _samples = keep
        // No event for a moment: the fingers have left the pad.
        releaseTimer.restart()
    }

    // The fingers left the pad: glide on with the speed of the last ~100 ms.
    function release() {
        releaseTimer.stop()
        const s = _samples
        _samples = []
        if (s.length < 2)
            return
        let sum = 0
        for (const e of s)
            sum += e.dy
        // (The first event only started the interval, so it adds distance but no time.)
        const span = (s[s.length - 1].t - s[0].t) / 1000 + 0.016
        const v = Math.max(-maxGlideSpeed, Math.min(maxGlideSpeed, sum / span))
        if (Math.abs(v) < minGlideSpeed)
            return
        _speed = v
        glide.running = true
    }

    function stopGlide() {
        glide.running = false
        _speed = 0
    }

    onMovementStarted: stopGlide()

    Timer {
        id: releaseTimer
        interval: 60
        onTriggered: root.release()
    }

    FrameAnimation {
        id: glide
        onTriggered: {
            const dt = frameTime
            const wanted = root.contentY + root._speed * dt
            const y = root._clamp(wanted)
            root.contentY = y
            root._speed *= Math.exp(-dt / root.glideTime)
            // At the end of the page, or slow enough to be at rest.
            if (y !== wanted || Math.abs(root._speed) < 20)
                running = false
        }
    }

    // Takes the touchpad's wheel events before the Flickable does. It takes no buttons, so
    // clicks and drags pass through to what is under it.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        z: 1000

        onWheel: wheel => {
            if (wheel.pixelDelta.y !== 0) {
                // (pixelDelta is positive when the content moves down.)
                root.scrollBy(-wheel.pixelDelta.y)
                wheel.accepted = true
            } else {
                wheel.accepted = false
            }
        }
    }
}
