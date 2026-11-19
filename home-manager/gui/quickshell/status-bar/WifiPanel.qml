pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Networking
import qs.shared

// The content of the Wi-Fi menu (networks, password), without a window or background of its own: the
// balanced bar puts it in its glass panel, WifiMenu.qml in a popup window.
Item {
    id: popup

    implicitWidth: 300
    implicitHeight: 320

    signal closeRequested()
    // The password field needs the keyboard.
    readonly property bool wantsKeyboard: selectedNetwork !== null

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

    Component.onCompleted: {
        if (visible && wifiDevice)
            wifiDevice.scannerEnabled = true
    }

    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (popup.selectedNetwork !== null) {
                popup.deselect()
            } else {
                popup.closeRequested()
            }
        }
    }

    onSelectedNetworkChanged: {
        if (selectedNetwork !== null) {
            Qt.callLater(function() {
                passwordScreen.passwordField.forceActiveFocus()
            })
        }
    }

    // Back to the list: forget the selected network, the typed password and the error.
    function deselect() {
        selectedNetwork = null
        password = ""
        connectionError = ""
    }

    // Asks for the password of `network`.
    function select(network) {
        selectedNetwork = network
        password = ""
        connectionError = ""
    }

    function connectSelectedNetwork() {
        if (!selectedNetwork || password.length === 0)
        return

        connectionError = ""
        selectedNetwork.connectWithPsk(password)
    }

    // ================================================================
    // MAIN BACKGROUND
    // ================================================================

    Item {
        anchors {
            fill: parent
            margins: 6
        }

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

                delegate: WifiNetworkRow {
                    panel: popup
                }
            }
        }

        // ============================================================
        // PASSWORD SCREEN
        // ============================================================

        WifiPasswordScreen {
            id: passwordScreen
            panel: popup
            anchors.fill: parent
            anchors.margins: 10
        }

        Connections {
            target: popup.selectedNetwork

            function onConnectedChanged() {
                if (popup.selectedNetwork?.connected) {
                    popup.deselect()
                }
            }

            function onConnectionFailed(reason) {
                popup.connectionError = "Connection failed."
            }
        }
    }
}
