import QtQuick

// The power-profile menu as a popup window (the notch layout). The content is PowerPanel.qml.
BarMenu {
    id: popup

    implicitWidth: 180
    implicitHeight: 160

    PowerPanel {
        anchors.fill: parent
        anchors.margins: -popup.cardMargin
        visible: popup.visible
        onCloseRequested: popup.visible = false
    }
}
