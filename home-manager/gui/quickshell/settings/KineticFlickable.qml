import QtQuick
import qs.shared

// A Flickable with touchpad momentum (shared/KineticScroll.qml), for the settings pages.
Flickable {
    id: root

    boundsBehavior: Flickable.StopAtBounds

    function stopGlide() {
        scroll.stopGlide()
    }

    KineticScroll {
        id: scroll
        target: root
    }
}
