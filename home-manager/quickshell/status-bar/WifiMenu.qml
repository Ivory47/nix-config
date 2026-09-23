pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Networking

PopupWindow {
    id: popup

    implicitWidth: 300
    implicitHeight: 320

    color: "transparent"

    grabFocus: true

    property var selectedNetwork: null
    property string password: ""
    property bool passwordVisible: false
    property string connectionError: ""

    property var wifiDevice: {
        const devices = Networking.devices?.values ?? []
        return devices.find(device => device.type === DeviceType.Wifi) ?? null
    }

    property var networks: wifiDevice?.networks?.values ?? []

    onVisibleChanged: {
        if (visible && wifiDevice) {
            wifiDevice.scannerEnabled = true
        }

        if (!visible) {
            selectedNetwork = null
            password = ""
            connectionError = ""
        }
    }

    onSelectedNetworkChanged: {
        if (selectedNetwork !== null) {
            Qt.callLater(function() {
                passwordInput.forceActiveFocus()
            })
        }
    }

    function connectSelectedNetwork() {
        if (!selectedNetwork || password.length === 0)
        return

        connectionError = ""
        selectedNetwork.connectWithPsk(password)
    }

    // ================================================================
    // SHADOW
    // ================================================================

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

    // ================================================================
    // MAIN BACKGROUND
    // ================================================================

    Rectangle {
        anchors {
            fill: parent
            margins: 6
        }

        color: Theme.background
        radius: 6

        // ============================================================
        // NETWORK LIST
        // ============================================================

        Column {
            visible: popup.selectedNetwork === null

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

                delegate: Item {
                    id: networkRow

                    required property var modelData

                    width: ListView.view.width
                    height: 38

                    property bool rowHovered: rowHoverHandler.hovered

                    Rectangle {
                        anchors.fill: parent

                        radius: 5

                        color: {
                            if (networkRow.modelData.connected)
                            return Theme.surfaceAlt

                            if (networkRow.rowHovered)
                            return Theme.surface

                            return "transparent"
                        }
                    }

                    // ------------------------------------------------
                    // Network name
                    // ------------------------------------------------

                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 8
                            verticalCenter: parent.verticalCenter
                        }

                        width: parent.width - 95

                        text: networkRow.modelData.name || "Hidden network"

                        color: Theme.text
                        font.pixelSize: 13

                        elide: Text.ElideRight
                    }

                    // ------------------------------------------------
                    // Network status icon
                    // ------------------------------------------------

                    Text {
                        id: networkIcon

                        anchors {
                            right: parent.right
                            rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }

                        text: {
                            if (networkRow.modelData.connected)
                            return "✓"

                            if (networkRow.modelData.stateChanging)
                            return "…"

                            if (networkRow.modelData.known)
                            return "󰍁"

                            return ""
                        }

                        color: networkRow.modelData.connected
                        ? Theme.green
                        : Theme.textMuted

                        font.pixelSize: 15
                    }

                    // ------------------------------------------------
                    // Trash icon
                    // ------------------------------------------------

                    Text {
                        id: forgetIcon

                        visible: networkRow.modelData.known
                        && !networkRow.modelData.connected
                        && networkRow.rowHovered

                        anchors {
                            right: networkIcon.left
                            rightMargin: 10
                            verticalCenter: parent.verticalCenter
                        }

                        text: "󰆴"

                        color: forgetMouse.containsMouse
                        ? Theme.red
                        : Theme.textMuted

                        font.pixelSize: 15
                    }

                    // ------------------------------------------------
                    // Tracks hovering over the entire row.
                    //
                    // This does NOT handle clicks, so it cannot
                    // interfere with the row or trash button.
                    // ------------------------------------------------

                    HoverHandler {
                        id: rowHoverHandler
                    }

                    // ------------------------------------------------
                    // Normal row click
                    //
                    // Covers the entire row, but the trash button
                    // has a higher z-index and therefore receives
                    // clicks on the trash.
                    // ------------------------------------------------

                    MouseArea {
                        id: rowMouse

                        anchors.fill: parent

                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        z: 1

                        onClicked: {
                            if (networkRow.modelData.connected) {
                                networkRow.modelData.disconnect()
                                return
                            }

                            if (networkRow.modelData.known) {
                                networkRow.modelData.connect()
                                return
                            }

                            popup.selectedNetwork = networkRow.modelData
                            popup.password = ""
                            popup.connectionError = ""
                        }
                    }

                    // ------------------------------------------------
                    // Trash button
                    //
                    // Only this small area handles forgetting.
                    // ------------------------------------------------

                    MouseArea {
                        id: forgetMouse

                        visible: networkRow.modelData.known
                        && !networkRow.modelData.connected
                        && networkRow.rowHovered

                        anchors {
                            right: networkIcon.left
                            rightMargin: 3
                            verticalCenter: parent.verticalCenter
                        }

                        width: 24
                        height: 24

                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        z: 2

                        onClicked: {
                            networkRow.modelData.forget()
                        }
                    }

                    // ------------------------------------------------
                    // Connection failure
                    // ------------------------------------------------

                    Connections {
                        target: networkRow.modelData

                        function onConnectionFailed(reason) {
                            console.log(
                                "Wi-Fi connection failed:",
                                networkRow.modelData.name,
                                reason
                            )

                            if (popup.selectedNetwork === networkRow.modelData) {
                                popup.connectionError = "Connection failed."
                            }
                        }
                    }
                }
            }
        }

        // ============================================================
        // PASSWORD SCREEN
        // ============================================================

        Column {
            visible: popup.selectedNetwork !== null

            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            Text {
                text: "Connect to Wi-Fi"

                color: Theme.text
                font.pixelSize: 14
            }

            Rectangle {
                width: parent.width
                height: 1

                color: Theme.surfaceAlt
            }

            Text {
                width: parent.width

                text: popup.selectedNetwork?.name ?? ""

                color: Theme.textSecondary
                font.pixelSize: 13

                elide: Text.ElideRight
            }

            Text {
                text: "Password"

                color: Theme.textMuted
                font.pixelSize: 12
            }

            Rectangle {
                width: parent.width
                height: 34

                color: Theme.surface
                radius: 5

                TextInput {
                    id: passwordInput

                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter

                        leftMargin: 8
                        rightMargin: 8
                    }

                    color: Theme.text
                    font.pixelSize: 13

                    echoMode: popup.passwordVisible
                    ? TextInput.Normal
                    : TextInput.Password

                    text: popup.password

                    onTextChanged: {
                        popup.password = text
                    }

                    Keys.onReturnPressed: {
                        popup.connectSelectedNetwork()
                    }
                }
            }

            Text {
                visible: popup.connectionError !== ""

                width: parent.width

                text: popup.connectionError

                color: Theme.red
                font.pixelSize: 12

                wrapMode: Text.Wrap
            }

            Item {
                width: parent.width
                height: 32

                // Cancel
                Rectangle {
                    anchors.left: parent.left

                    width: 70
                    height: 32

                    radius: 5

                    color: cancelMouse.containsMouse
                    ? Theme.surface
                    : "transparent"

                    Text {
                        anchors.centerIn: parent

                        text: "Cancel"

                        color: Theme.text
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: cancelMouse

                        anchors.fill: parent

                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            popup.selectedNetwork = null
                            popup.password = ""
                            popup.connectionError = ""
                        }
                    }
                }

                // Connect
                Rectangle {
                    anchors.right: parent.right

                    width: 80
                    height: 32

                    radius: 5

                    color: connectMouse.containsMouse
                    ? Theme.surfaceAlt
                    : Theme.surface

                    Text {
                        anchors.centerIn: parent

                        text: "Connect"

                        color: Theme.text
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: connectMouse

                        anchors.fill: parent

                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            popup.connectSelectedNetwork()
                        }
                    }
                }
            }
        }

        // ============================================================
        // SELECTED NETWORK CONNECTION HANDLING
        // ============================================================

        Connections {
            target: popup.selectedNetwork

            function onConnectedChanged() {
                if (popup.selectedNetwork?.connected) {
                    popup.selectedNetwork = null
                    popup.password = ""
                    popup.connectionError = ""
                }
            }

            function onConnectionFailed(reason) {
                popup.connectionError = "Connection failed."
            }
        }
    }
}
