pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Networking

PopupWindow {
    id: popup

    implicitWidth: 300
    implicitHeight: 420

    color: "transparent"

    grabFocus: true

    property var wifiDevice: {
        const devices = Networking.devices?.values ?? []
        return devices.find(device => device.type === DeviceType.Wifi) ?? null
    }

    property var networks: wifiDevice?.networks?.values ?? []

    onVisibleChanged: {
        if (visible && wifiDevice) {
            wifiDevice.scannerEnabled = true
        }
    }

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
    }

    Rectangle {
        anchors {
            fill: parent
            margins: 6
        }

        color: Theme.background
        radius: 6

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 5

            Text {
                text: "Wi-Fi"
                color: Theme.text
                font.pixelSize: 14
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.surfaceAlt
            }

            Text {
                visible: !popup.wifiDevice

                text: "No Wi-Fi device"
                color: Theme.textMuted
                font.pixelSize: 13
            }

            Text {
                visible: popup.wifiDevice && popup.networks.length === 0

                text: popup.wifiDevice?.scannerEnabled
                    ? "Scanning..."
                    : "No networks found"

                color: Theme.textMuted
                font.pixelSize: 13
            }

            ListView {
                visible: popup.networks.length > 0

                width: parent.width
                height: parent.height - y

                clip: true

                spacing: 2

                model: popup.networks

                delegate: Rectangle {
                    required property var modelData

                    width: ListView.view.width
                    height: 38
                    radius: 5

                    color: {
                        if (modelData.connected)
                            return Theme.surfaceAlt

                        if (mouse.containsMouse)
                            return Theme.surface

                        return "transparent"
                    }

                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 8
                            verticalCenter: parent.verticalCenter
                        }

                        width: parent.width - 55

                        text: modelData.name || "Hidden network"
                        color: Theme.text
                        font.pixelSize: 13

                        elide: Text.ElideRight
                    }

                    Text {
                        anchors {
                            right: parent.right
                            rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }

                        text: {
                            if (modelData.connected)
                                return "✓"

                            if (modelData.stateChanging)
                                return "…"

                            if (modelData.known)
                                return "󰌪"

                            return ""
                        }

                        color: modelData.connected
                            ? Theme.green
                            : Theme.textMuted

                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: mouse

                        anchors.fill: parent
                        hoverEnabled: true

                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            if (modelData.connected) {
                                modelData.disconnect()
                                return
                            }

                            if (modelData.known) {
                                modelData.connect()
                                return
                            }

                            // Password handling comes next.
                        }
                    }

                    Connections {
                        target: modelData

                        function onConnectionFailed(reason) {
                            console.log(
                                "Wi-Fi connection failed:",
                                modelData.name,
                                reason
                            )
                        }
                    }
                }
            }
        }
    }
}
