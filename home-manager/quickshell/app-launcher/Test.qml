import Quickshell
import QtQuick

PanelWindow {
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    LauncherModel {
        id: launcherModel
    }

    Rectangle {
        anchors.centerIn: parent

        width: 500
        height: 600

        color: Theme.background
        radius: Theme.radiusLarge

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: Theme.spacingSmall

            Text {
                text: "Applications: " + launcherModel.applications.values.length
                color: Theme.text
                font.pixelSize: Theme.textLarge
            }

            ListView {
                width: parent.width
                height: parent.height - 50

                spacing: 6

                model: launcherModel.applications

                delegate: LauncherItem {
                    required property var modelData

                    app: modelData

                    width: ListView.view.width
                }
            }
        }
    }
}
