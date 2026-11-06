import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import qs.shared
import qs.shared.glass

PanelWindow {
    id: statusBar
    WlrLayershell.namespace: "statusbar"

    anchors {
        top: true
        left: true
        right: true
    }

    // The glass needs the surface to be a whole number of real pixels (see GlassGeometry),
    // which at a fractional scale can mean a pixel or two more than Theme.statusBarHeight.
    implicitHeight: GlassGeometry.alignedSize(Theme.statusBarHeight, statusBar.devicePixelRatio)

    color: "transparent"

    property bool showing: true
    property string currentTime: Qt.formatDateTime(new Date(), "HH:mm")

    Timer {
        interval: 1000
        running: true
        repeat: true

        onTriggered: {
            currentTime = Qt.formatDateTime(new Date(), "HH:mm")
        }
    }

    onShowingChanged: {
        barContent.state = showing ? "visible" : "hidden"
    }

    Item {
        id: barContent

        anchors.fill: parent

        property real visibleAmount: 1
        property int fadeDuration: 150

        state: "visible"

        states: [
            State {
                name: "visible"

                PropertyChanges {
                    target: barContent
                    visibleAmount: 1
                }
            },

            State {
                name: "hidden"

                PropertyChanges {
                    target: barContent
                    visibleAmount: 0
                }
            }

        ]

        transitions: [
            Transition {
                from: "visible"
                to: "hidden"

                NumberAnimation {
                    property: "visibleAmount"
                    duration: barContent.fadeDuration
                    easing.type: Easing.InOutCubic
                }
            },

            Transition {
                from: "hidden"
                to: "visible"

                NumberAnimation {
                    property: "visibleAmount"
                    duration: barContent.fadeDuration
                    easing.type: Easing.InOutCubic
                }
            }
        ]

        // Live liquid glass (shared/glass): the real background behind the bar, blurred and
        // refracted on the GPU. Its look is this GlassStyle; the blur radius is on the backdrop.
        // Only for measuring (glassBackdrop.glassEnabled): the bar without glass.
        Rectangle {
            anchors.fill: parent
            visible: !glassBackdrop.glassEnabled
            color: Qt.rgba(0.12, 0.12, 0.18, 0.55)
        }

        GlassPanel {
            anchors.fill: parent
            visible: glassBackdrop.glassEnabled
            backdrop: glassBackdrop
            style: GlassStyle {}
        }

        // One opaque pixel at the top left: says which version of the bar a capture holds.
        GlassTag {
            backdrop: glassBackdrop
        }

        Rectangle {
            anchors.fill: parent

            color: "transparent"

            // opacity: statusBar.showing ? 1 : 0
            //
            // Behavior on opacity {
            //     NumberAnimation {
            //         duration: statusBar.fadeDuration
            //     }
            // }

            Row {
                anchors.centerIn: parent

                spacing: 10

                Repeater {
                    model: 5

                    Text {
                        required property int index

                        text: (index + 1).toString()

                        color: Hyprland.focusedWorkspace?.id === index + 1
                        ? Theme.text
                        : Theme.textMuted
                        font.pixelSize: 14
                    }
                }
            }

            Row {
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    rightMargin: 10
                }

                spacing: 15

                Wifi {}

                Audio {}

                Text {
                    text: statusBar.currentTime
                    color: Theme.text
                    font.pixelSize: 14
                }

                Battery {}
            }

            // bottom border
            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }

                height: 1
                color: Qt.alpha("#494965", 0.85)
            }
        }
    }

    // Captures and unmixes what is behind the bar. Outside of barContent, whose rendering it
    // keeps as "what was presented".
    GlassBackdrop {
        id: glassBackdrop
        composite: barContent
        blurRadius: 14
        ipcTarget: "glass"
        glassEnabled: Theme.glass
    }
}
