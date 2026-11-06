import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.shared
import qs.shared.glass

// The window, the glass and the opening and closing are GlassPopup's; see there.
GlassPopup {
    id: root
    WlrLayershell.namespace: "app-launcher"

    focusItem: searchField

    onPopupClosed: {
        // A fresh start the next time: no search text, first app selected, list at the top.
        searchField.text = ""
        appList.currentIndex = appList.count > 0 ? 0 : -1
        appList.positionViewAtBeginning()
    }

    function closeLauncher() {
        root.shown = false
    }

    Connections {
        target: Hyprland

        function onFocusedWorkspaceChanged() {
            root.shown = false
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle() {
            root.shown = !root.shown
        }

        function show() {
            root.shown = true
        }

        function hide() {
            root.shown = false
        }
    }

    LauncherModel {
        id: launcherModel
    }

    GlassListPanel {
        // Placed in the surface's coordinates (whole pixels, as the glass needs).
        x: Math.round(launcher.x)
        y: Math.round(launcher.y)
        width: launcher.width
        height: launcher.height

        popup: root
        field: searchField
        listView: appList
    }

    Rectangle {
        id: launcher

        anchors.centerIn: parent

        width: 600
        height: 400

        radius: Theme.radiusLarge
        color: "transparent"

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
                    color: "transparent" // drawn by the glass (hlRect0)
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
                    id: row

                    required property var modelData
                    required property int index

                    app: modelData
                    selected: index === appList.currentIndex

                    width: appList.width

                    // The glass highlights the row under the mouse (hlRect2).
                    onHoveredChanged: {
                        if (hovered)
                            root.hoveredItem = row
                        else if (root.hoveredItem === row)
                            root.hoveredItem = null
                    }

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
