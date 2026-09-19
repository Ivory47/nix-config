import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower

PanelWindow {
    id: statusBar

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Theme.statusBarHeight

    color: "transparent"

    property bool showing: true

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

        Rectangle {
            anchors.fill: parent

            color: Theme.background

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

                Audio {}

                Text {
                    text: Qt.formatDateTime(new Date(), "HH:mm")
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
                color: "#494965"
            }
        }
    }
}
