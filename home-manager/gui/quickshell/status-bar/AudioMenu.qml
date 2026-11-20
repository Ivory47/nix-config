import QtQuick

// The volume menu as a popup window (the notch layout). The content is AudioPanel.qml.
BarMenu {
    id: popup

    implicitWidth: 44
    implicitHeight: 165

    AudioPanel {
        anchors.fill: parent
        anchors.margins: -popup.cardMargin
        visible: popup.visible
    }
}
