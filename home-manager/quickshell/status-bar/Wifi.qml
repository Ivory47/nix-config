import QtQuick
import Quickshell
import Quickshell.Networking

Item {
    id: root

    width: icon.width
    height: icon.height

    readonly property var wifiDevice: {
        const devices = Networking.devices?.values ?? []
        return devices.find(device => device.type === DeviceType.Wifi) ?? null
    }

    readonly property var connectedNetwork: {
        const networks = wifiDevice?.networks?.values ?? []
        return networks.find(network => network.connected) ?? null
    }

    readonly property real signalStrength:
        connectedNetwork?.signalStrength ?? 0

    Text {
        id: icon

        anchors.centerIn: parent

        color: root.connectedNetwork
            ? Theme.text
            : Theme.textMuted

        font.pixelSize: 18

        text: {
            if (!root.wifiDevice)
                return "󰤮"

            if (!root.wifiDevice.connected)
                return "󰤭"

            if (root.signalStrength >= 75)
                return "󰤨"

            if (root.signalStrength >= 50)
                return "󰤥"

            if (root.signalStrength >= 25)
                return "󰤢"

            return "󰤟"
        }
    }

    MouseArea {
        anchors.fill: parent

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            // WifiMenu will be opened here later.
        }
    }
}
