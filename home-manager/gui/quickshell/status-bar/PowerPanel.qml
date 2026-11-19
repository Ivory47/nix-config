pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.shared

// The content of the power-profile menu (the battery's), without a window or background of its own: the
// balanced bar puts it in its glass panel, PowerMenu.qml in a popup window.
Item {
    id: popup

    implicitWidth: 180
    implicitHeight: 160

    signal closeRequested()

    property string currentProfile: ""

    // The current profile is read every time the menu is shown.
    Component.onCompleted: getProfile.running = true
    onVisibleChanged: if (visible) getProfile.running = true

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 5

        Text {
            text: "Power profile"
            color: Theme.text
            font.pixelSize: 14
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.surfaceAlt
        }

        Repeater {
            model: [
                { name: "Power Saver", profile: "power-saver" },
                { name: "Balanced", profile: "balanced" },
                { name: "Performance", profile: "performance" }
            ]

            Rectangle {
                required property var modelData

                width: parent.width
                height: 32
                radius: 5

                color: {
                    if (modelData.profile === popup.currentProfile)
                    return Theme.surfaceAlt

                    if (mouse.containsMouse)
                    return Theme.surface

                    return "transparent"
                }

                Text {
                    anchors.centerIn: parent

                    text: modelData.name
                    color: Theme.text
                    font.pixelSize: 13
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        currentProfile = modelData.profile

                        powerProfile.command = [
                            "powerprofilesctl",
                            "set",
                            modelData.profile
                        ]

                        powerProfile.running = true
                        popup.closeRequested()
                    }
                }
            }
        }
    }

    Process {
        id: getProfile

        command: ["powerprofilesctl", "get"]

        // removes new line
        stdout: StdioCollector {
            onStreamFinished: {
                popup.currentProfile = text.trim()
            }
        }
    }

    Process {
        id: powerProfile

        command: []
    }
}
