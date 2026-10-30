import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import qs.shared

PanelWindow {
    id: statusBar
    WlrLayershell.namespace: "statusbar"

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Theme.statusBarHeight

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

        // Shared backdrop blur (strength: Theme.backdropBlur)
        BackdropBlur {
            id: backdropBlur
            anchors.fill: parent
            screen: statusBar.screen
        }

        Rectangle {
            anchors.fill: parent
            visible: !backdropBlur.capturing

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
}
