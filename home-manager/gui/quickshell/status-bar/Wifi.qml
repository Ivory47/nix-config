import QtQuick
import Quickshell
import Quickshell.Networking
import qs.shared

Item {
    id: root

    // True: no popup menu of its own; a click only emits `toggled()` (the balanced bar shows the menu in
    // its own glass panel).
    property bool embedded: false
    signal toggled()

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
            if (root.embedded)
                root.toggled()
            else
                menuLoader.item.visible = !menuLoader.item.visible
        }
    }

    Loader {
        id: menuLoader
        active: !root.embedded
        sourceComponent: WifiMenu {
            id: wifiMenu

            visible: false

            anchor.item: root
            anchor.edges: Edges.Bottom | Edges.HCenter
            anchor.gravity: Edges.Bottom | Edges.HCenter
            anchor.margins.top: 24
        }
    }
}
