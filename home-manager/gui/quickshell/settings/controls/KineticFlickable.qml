import QtQuick
import qs.shared

// A Flickable with touchpad momentum (shared/KineticScroll.qml), for the settings pages.
Flickable {
    id: root

    boundsBehavior: Flickable.StopAtBounds

    function stopGlide() {
        scroll.stopGlide()
    }

    // A contentY inside the content (for scrolling to something).
    function clampContentY(y) {
        return scroll._clamp(y)
    }

    KineticScroll {
        id: scroll
        target: root
    }
}
