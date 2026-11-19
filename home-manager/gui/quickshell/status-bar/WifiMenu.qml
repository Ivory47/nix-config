import QtQuick
import qs.shared

// The Wi-Fi menu as a popup window (classic, islands and notch layouts). The content is WifiPanel.qml.
BarMenu {
    id: popup

    implicitWidth: 300
    implicitHeight: 320

    WifiPanel {
        anchors.fill: parent
        anchors.margins: -popup.cardMargin
        visible: popup.visible
    }
}
