import QtQuick
import qs.shared

// One network of the Wi-Fi list: click to connect or disconnect (a known one) or to ask for the password; the
// trash icon forgets a known one. `panel` is the WifiPanel.
Item {
    id: networkRow

    required property var panel

    required property var modelData

    width: ListView.view.width
    height: 38

    property bool rowHovered: rowHoverHandler.hovered

    Rectangle {
        anchors.fill: parent

        radius: 5

        color: {
            if (networkRow.modelData.connected)
            return Theme.surfaceAlt

            if (networkRow.rowHovered)
            return Theme.surface

            return "transparent"
        }
    }

    // ------------------------------------------------
    // Network name
    // ------------------------------------------------

    Text {
        anchors {
            left: parent.left
            leftMargin: 8
            verticalCenter: parent.verticalCenter
        }

        width: parent.width - 95

        text: networkRow.modelData.name || "Hidden network"

        color: Theme.text
        font.pixelSize: 13

        elide: Text.ElideRight
    }

    // ------------------------------------------------
    // Network status icon
    // ------------------------------------------------

    Text {
        id: networkIcon

        anchors {
            right: parent.right
            rightMargin: 8
            verticalCenter: parent.verticalCenter
        }

        text: {
            if (networkRow.modelData.connected)
            return "✓"

            if (networkRow.modelData.stateChanging)
            return "…"

            if (networkRow.modelData.known)
            return "󰍁"

            return ""
        }

        color: networkRow.modelData.connected
        ? Theme.green
        : Theme.textMuted

        font.pixelSize: 15
    }

    // ------------------------------------------------
    // Trash icon
    // ------------------------------------------------

    Text {
        id: forgetIcon

        visible: networkRow.modelData.known
        && !networkRow.modelData.connected
        && networkRow.rowHovered

        anchors {
            right: networkIcon.left
            rightMargin: 10
            verticalCenter: parent.verticalCenter
        }

        text: "󰆴"

        color: forgetMouse.containsMouse
        ? Theme.red
        : Theme.textMuted

        font.pixelSize: 15
    }

    // ------------------------------------------------
    // Tracks hovering over the entire row.
    //
    // This does NOT handle clicks, so it cannot
    // interfere with the row or trash button.
    // ------------------------------------------------

    HoverHandler {
        id: rowHoverHandler
    }

    // ------------------------------------------------
    // Normal row click
    //
    // Covers the entire row, but the trash button
    // has a higher z-index and therefore receives
    // clicks on the trash.
    // ------------------------------------------------

    MouseArea {
        id: rowMouse

        anchors.fill: parent

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        z: 1

        onClicked: {
            if (networkRow.modelData.connected) {
                networkRow.modelData.disconnect()
                return
            }

            if (networkRow.modelData.known) {
                networkRow.modelData.connect()
                return
            }

            panel.select(networkRow.modelData)
        }
    }

    // ------------------------------------------------
    // Trash button
    //
    // Only this small area handles forgetting.
    // ------------------------------------------------

    MouseArea {
        id: forgetMouse

        visible: networkRow.modelData.known
        && !networkRow.modelData.connected
        && networkRow.rowHovered

        anchors {
            right: networkIcon.left
            rightMargin: 3
            verticalCenter: parent.verticalCenter
        }

        width: 24
        height: 24

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        z: 2

        onClicked: {
            networkRow.modelData.forget()
        }
    }

    // ------------------------------------------------
    // Connection failure
    // ------------------------------------------------

    Connections {
        target: networkRow.modelData

        function onConnectionFailed(reason) {
            console.log(
                "Wi-Fi connection failed:",
                networkRow.modelData.name,
                reason
            )

            if (panel.selectedNetwork === networkRow.modelData) {
                panel.connectionError = "Connection failed."
            }
        }
    }
}
