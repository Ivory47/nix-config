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

        font.pixelSize: 14

        text: {
            if (!root.wifiDevice)
                return "󰤮 "

            if (!root.wifiDevice.connected)
                return "󰤭 "

            if (root.signalStrength >= 75)
                return "󰤨 "

            if (root.signalStrength >= 50)
                return "󰤥 "

            if (root.signalStrength >= 25)
                return "󰤢 "

            return "󰤟 "
        }
    }

    MouseArea {
        anchors.fill: parent

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            wifiMenu.visible = !wifiMenu.visible
        }
    }

    WifiMenu {
        id: wifiMenu

        visible: false

        anchor.item: root
        anchor.edges: Edges.Bottom | Edges.HCenter
        anchor.gravity: Edges.Bottom | Edges.HCenter
        anchor.margins.top: 24
    }
}
