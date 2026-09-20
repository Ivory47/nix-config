import QtQuick
import Quickshell
import Quickshell.Services.UPower

Item {
    id: battery 

    visible: UPower.displayDevice.isLaptopBattery

    implicitWidth: batteryText.implicitWidth
    implicitHeight: batteryText.implicitHeight

    Text {
        id: batteryText

        property real batteryLevel: UPower.displayDevice.percentage

        text: {
            let percent = Math.round(batteryLevel * 100)

            if (percent >= 90)
            return "󰁹 " + percent + "%"
            else if (percent >= 80)
            return "󰂂 " + percent + "%"
            else if (percent >= 75)
            return "󰂁 " + percent + "%"
            else if (percent >= 70)
            return "󰂀 " + percent + "%"
            else if (percent >= 60)
            return "󰁿 " + percent + "%"
            else if (percent >= 50)
            return "󰁾 " + percent + "%"
            else if (percent >= 40)
            return "󰁽 " + percent + "%"
            else if (percent >= 30)
            return "󰁼 " + percent + "%"
            else if (percent >= 10)
            return "󰁻 " + percent + "%"
            else
            return "󰂃 " + percent + "%"
        }

        color: {
            let percent = batteryLevel * 100

            if (percent > 30)
            return Theme.green
            else if (percent > 10)
            return Theme.orange
            else
            return Theme.red
        }

        font.pixelSize: 14
    }

    MouseArea {
        anchors.fill: parent

        cursorShape: Qt.PointingHandCursor

        onClicked: {
            powerMenu.visible = !powerMenu.visible
        }
    }

    PowerMenu {
        id: powerMenu

        visible: false

        anchor.item: battery
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.margins.top: 24
    }
}
