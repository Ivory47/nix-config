import QtQuick
import qs.shared

// The power-profile menu as a popup window (classic, islands and notch layouts). The content is PowerPanel.qml.
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
