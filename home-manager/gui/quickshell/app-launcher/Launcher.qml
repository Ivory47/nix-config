import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick.Effects
import qs.shared
import qs.shared.glass

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
    // Cover the whole output, over the bar: the glass needs the surface at the output's top left.
    exclusionMode: ExclusionMode.Ignore

    // The window stays mapped: Quickshell destroys and re-creates the Qt window when `visible`
    // goes false and true again, and the glass items crash that re-creation (segfault in
    // QQuickWindow::maybeUpdate). So only `shown` changes: no input, no focus and no content
    // while hidden, and the glass capture is off.
    property bool shown: false

    focusable: shown
    mask: shown ? null : emptyMask

    Region {
        id: emptyMask
    }

    color: "transparent"

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

            if (root.shown)
            searchField.forceActiveFocus()
        }

        function show() {
            root.shown = true
            searchField.forceActiveFocus()
        }

        function hide() {
            root.shown = false
        }
    }

    LauncherModel {
        id: launcherModel
    }

    Item {
        id: content
        anchors.fill: parent
        visible: root.shown

        RectangularShadow {
            anchors.fill: launcher

            radius: launcher.radius

            blur: 14
            spread: 2

            color: Theme.shadowColor

            offset.x: 0
            offset.y: 4
        }

        GlassPanel {
            // Placed in the backdrop's coordinates (whole pixels, as the glass needs).
            x: Math.round(launcher.x)
            y: Math.round(launcher.y)
            width: launcher.width
            height: launcher.height

            backdrop: glassBackdrop
            style: GlassStyle {
                cornerRadius: Theme.radiusLarge
                edges: Qt.vector4d(1, 1, 1, 1)

                // The launcher's old background colour, over the blur: like an acrylic
                // taskbar, only more translucent. Raise tintStrength for more colour.
                tint: Theme.background
                tintStrength: 0.65
            }
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
                        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.6)
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

        // One opaque pixel at the top left: says which version of the surface a capture holds.
        GlassTag {
            backdrop: glassBackdrop
        }
    }

    // Live glass (shared/glass): captures and unmixes what is behind this surface. Only while shown.
    GlassBackdrop {
        id: glassBackdrop
        composite: content
        blurRadius: 14
        ipcTarget: "glass"
        active: root.shown
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
