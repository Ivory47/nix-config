import QtQuick

// The volume menu as a popup window (classic, islands and notch layouts). The content is AudioPanel.qml.
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
