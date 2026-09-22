import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick.Effects

PanelWindow {
    id: root
    WlrLayershell.namespace: "app-launcher"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay

    visible: false
    focusable: true

    color: "transparent"

    function closeLauncher() {
        root.visible = false
    }

    Connections {
        target: Hyprland

        function onFocusedWorkspaceChanged() {
            root.visible = false
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle() {
            root.visible = !root.visible

            if (root.visible)
            searchField.forceActiveFocus()
        }

        function show() {
            root.visible = true
            searchField.forceActiveFocus()
        }

        function hide() {
            root.visible = false
        }
    }

    LauncherModel {
        id: launcherModel
    }

    RectangularShadow {
        anchors.fill: launcher

        radius: launcher.radius

        blur: 14
        spread: 2

        color: Theme.shadowColor

        offset.x: 0
        offset.y: 4
    }

    Rectangle {
        id: launcher

        anchors.centerIn: parent

        width: 600
        height: 400

        radius: Theme.radiusLarge
        color: Theme.background

        border.width: 1
        border.color: Theme.surfaceAlt

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingLarge

            spacing: Theme.spacingMedium

            TextField {
                id: searchField

                width: parent.width
                height: 50

                leftPadding: Theme.spacingMedium 
                rightPadding: Theme.spacingMedium

                placeholderText: "Search applications..."
                font.pixelSize: Theme.textMedium

                color: Theme.text
                placeholderTextColor: Theme.textMuted

                text: launcherModel.searchText

                onTextChanged: {
                    launcherModel.searchText = text
                }

                background: Rectangle {
                    radius: Theme.radiusMedium
                    color: Theme.surface
                }

                Component.onCompleted: {
                    forceActiveFocus()
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        root.closeLauncher()
                        event.accepted = true
                    }

                    else if (event.key === Qt.Key_C &&
                    (event.modifiers & Qt.ControlModifier)) {
                        root.closeLauncher()
                        event.accepted = true
                    }

                    else if (event.key === Qt.Key_Down) {
                        if (appList.count > 0) {
                            appList.currentIndex =
                            Math.min(
                                appList.currentIndex + 1,
                                appList.count - 1
                            )
                        }

                        event.accepted = true
                    }

                    else if (event.key === Qt.Key_Up) {
                        if (appList.count > 0) {
                            appList.currentIndex =
                            Math.max(
                                appList.currentIndex - 1,
                                0
                            )
                        }

                        event.accepted = true
                    }

                    else if (event.key === Qt.Key_Return ||
                    event.key === Qt.Key_Enter) {
                        if (appList.currentIndex >= 0 &&
                        appList.currentIndex < appList.count) {

                            launcherModel.launch(
                                launcherModel.filteredApplications[
                                    appList.currentIndex
                                ]
                            )

                            root.closeLauncher()
                        }

                        event.accepted = true
                    }

                    else if (event.key === Qt.Key_Down) {
                        if (appList.count > 0) {
                            appList.currentIndex =
                                Math.min(
                                    appList.currentIndex + 1,
                                    appList.count - 1
                                )
                        }

                        event.accepted = true
                    }

                    else if (event.key === Qt.Key_Up) {
                        if (appList.count > 0) {
                            appList.currentIndex =
                                Math.max(
                                    appList.currentIndex - 1,
                                    0
                                )
                        }

                        event.accepted = true
                    }
                }
            }

            ListView {
                id: appList

                width: parent.width
                height: parent.height
                    - searchField.height
                    - Theme.spacingMedium

                spacing: Theme.spacingSmall

                clip: true

                model: launcherModel.filteredApplications

                currentIndex: count > 0 ? 0 : -1

                delegate: LauncherItem {
                    required property var modelData
                    required property int index

                    app: modelData
                    selected: index === appList.currentIndex

                    width: appList.width

                    onLaunched: {
                        root.closeLauncher()
                    }
                }
            }
        }
    }

    Connections {
        target: launcherModel

        function onFilteredApplicationsChanged() {
            appList.currentIndex =
                launcherModel.filteredApplications.length > 0
                    ? 0
                    : -1
        }
    }
}
