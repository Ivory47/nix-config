import QtQuick

// The Wi-Fi menu as a popup window (the notch layout). The content is WifiPanel.qml.
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
