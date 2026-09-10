pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io

PopupWindow {
    id: popup

    implicitWidth: 180
    implicitHeight: 160

    color: "transparent"

    grabFocus: true

    onVisibleChanged: {
        if (visible) {
            getProfile.running = true
        } 
    }

    property string currentProfile: ""

    Rectangle {
        anchors {
            fill: parent
            margins: 6
        }
        color: Theme.background
        radius: 6

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.shadowColor
            shadowBlur: 0.5
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 3
        }

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
                            popup.visible = false
                        }
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
                currentProfile = text.trim()
            }
        }
    }

    Process {
        id: powerProfile

        command: []
    }
}
