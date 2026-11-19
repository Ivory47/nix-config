import QtQuick
import QtQuick.Effects
import Quickshell
import qs.shared

// The volume menu as a popup window (classic, islands and notch layouts). The content is AudioPanel.qml.
PopupWindow {
    id: popup

    implicitWidth: 44
    implicitHeight: 165

    color: "transparent"
    grabFocus: true

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

        AudioPanel {
            anchors.fill: parent
            anchors.margins: -6
            visible: popup.visible
        }
    }
}
