import QtQuick
import Quickshell

PanelWindow {
    id: osd

    signal hidden()

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    exclusionMode: ExclusionMode.Ignore

    color: "transparent"

    // Keep the window mapped permanently.
    visible: true

    // Generic positioning API.
    property int contentHorizontalAlignment: Qt.AlignHCenter
    property int contentVerticalAlignment: Qt.AlignVCenter
    property int contentMargin: 0

    property bool showing: false
    property int fadeInDuration: 100
    property int fadeOutDuration: 200
    property int hideDelay: 2000

    default property alias content: contentContainer.data

    /*
     * The container automatically sizes itself to whatever
     * visual content the individual OSD provides.
     */
    Item {
        id: contentContainer

        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height

        width: implicitWidth
        height: Theme.statusBarHeight

        x: {
            if (osd.contentHorizontalAlignment === Qt.AlignLeft)
                return osd.contentMargin

            if (osd.contentHorizontalAlignment === Qt.AlignRight)
                return parent.width - width - osd.contentMargin

            return (parent.width - width) / 2
        }

        y: {
            if (osd.contentVerticalAlignment === Qt.AlignTop)
                return osd.contentMargin

            if (osd.contentVerticalAlignment === Qt.AlignBottom)
                return parent.height - height - osd.contentMargin

            return (parent.height - height) / 2
        }

        opacity: 0

        NumberAnimation {
            id: fadeAnimation

            target: contentContainer
            property: "opacity"

            to: osd.showing ? 1 : 0

            duration: osd.showing
                ? osd.fadeInDuration
                : osd.fadeOutDuration

            onFinished: {
                if (!osd.showing)
                    osd.hidden()
            }
        }
    }

    /*
     * Only the actual OSD content receives input.
     *
     * When hidden, the region becomes 0x0 and the fullscreen
     * window effectively becomes click-through.
     */
    mask: Region {
        x: osd.showing ? contentContainer.x : 0
        y: osd.showing ? contentContainer.y : 0
        width: osd.showing ? contentContainer.width : 0
        height: osd.showing ? contentContainer.height : 0
    }

    Timer {
        id: hideTimer

        interval: osd.hideDelay

        onTriggered: {
            hide()
        }
    }

    function show() {
        hideTimer.restart()

        fadeAnimation.stop()

        osd.showing = true

        if (osd.fadeInDuration === 0) {
            contentContainer.opacity = 1
        } else {
            fadeAnimation.restart()
        }
    }

    function hide() {
        hideTimer.stop()

        fadeAnimation.stop()

        osd.showing = false

        if (osd.fadeOutDuration === 0) {
            contentContainer.opacity = 0
        } else {
            fadeAnimation.restart()
        }
    }

    function restartTimer() {
        hideTimer.restart()
    }
}
