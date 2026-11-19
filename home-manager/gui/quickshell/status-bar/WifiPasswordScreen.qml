import QtQuick
import qs.shared

// The password screen of the Wi-Fi panel: asks for the password of the selected network. `panel` is the WifiPanel.
Column {
    id: screen

    required property var panel
    readonly property alias passwordField: passwordInput

    visible: panel.selectedNetwork !== null

    anchors.fill: parent
    anchors.margins: 10
    spacing: 8

    Text {
        text: "Connect to Wi-Fi"

        color: Theme.text
        font.pixelSize: 14
    }

    Rectangle {
        width: parent.width
        height: 1

        color: Theme.surfaceAlt
    }

    Text {
        width: parent.width

        text: panel.selectedNetwork?.name ?? ""

        color: Theme.textSecondary
        font.pixelSize: 13

        elide: Text.ElideRight
    }

    Text {
        text: "Password"

        color: Theme.textMuted
        font.pixelSize: 12
    }

    Rectangle {
        width: parent.width
        height: 34

        color: Theme.surface
        radius: 5

        TextInput {
            id: passwordInput

            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter

                leftMargin: 8
                rightMargin: 8
            }

            color: Theme.text
            font.pixelSize: 13

            echoMode: panel.passwordVisible
            ? TextInput.Normal
            : TextInput.Password

            text: panel.password

            onTextChanged: {
                panel.password = text
            }

            Keys.onReturnPressed: {
                panel.connectSelectedNetwork()
            }
        }
    }

    Text {
        visible: panel.connectionError !== ""

        width: parent.width

        text: panel.connectionError

        color: Theme.red
        font.pixelSize: 12

        wrapMode: Text.Wrap
    }

    Item {
        width: parent.width
        height: 32

        // Cancel
        Rectangle {
            anchors.left: parent.left

            width: 70
            height: 32

            radius: 5

            color: cancelMouse.containsMouse
            ? Theme.surface
            : "transparent"

            Text {
                anchors.centerIn: parent

                text: "Cancel"

                color: Theme.text
                font.pixelSize: 13
            }

            MouseArea {
                id: cancelMouse

                anchors.fill: parent

                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    panel.deselect()
                }
            }
        }

        // Connect
        Rectangle {
            anchors.right: parent.right

            width: 80
            height: 32

            radius: 5

            color: connectMouse.containsMouse
            ? Theme.surfaceAlt
            : Theme.surface

            Text {
                anchors.centerIn: parent

                text: "Connect"

                color: Theme.text
                font.pixelSize: 13
            }

            MouseArea {
                id: connectMouse

                anchors.fill: parent

                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    panel.connectSelectedNetwork()
                }
            }
        }
    }
}

// ============================================================
// SELECTED NETWORK CONNECTION HANDLING
// ============================================================
