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
    // The list row under the mouse, if any (highlighted by the glass).
    property Item hoveredItem: null

    // Take the keyboard exclusively while shown. (`focusable` only asks for it on demand, which
    // the compositor does not always grant when the window was already mapped, so typing
    // sometimes went elsewhere.)
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // The glass is drawn from the background it saved the last time the launcher was open, and
    // it subtracts that old picture of what leaks through it: when the screen behind has changed,
    // the old text shows up inverted until the first new capture. So until the pipeline has
    // taken fresh captures (a few frames) the glass does not subtract anything (cancelLeak):
    // only a faint trace of the real background shows through, and the launcher is shown at once.
    property bool revealed: false
    property int flipsAtOpen: 0

    // How much of the leak the glass cancels: 0 until the pipeline is fresh, then up to 1 over
    // a short ramp, so that no single frame can jump (a refused capture would show the old
    // picture for one frame).
    property real cancelAmount: 0

    NumberAnimation {
        id: cancelRamp
        target: root
        property: "cancelAmount"
        from: 0
        to: 1
        duration: 150
    }

    function reveal() {
        revealTimer.stop()
        revealed = true
        cancelRamp.restart()
    }

    Timer {
        // In case no capture comes (nothing changed behind, so the old picture is right).
        id: revealTimer
        interval: 400
        onTriggered: root.reveal()
    }

    Connections {
        target: glassBackdrop

        function onFlipsChanged() {
            // Two updates: the first capture may predate the surface (no tag in it) and be refused.
            if (root.shown && !root.revealed && glassBackdrop.flips >= root.flipsAtOpen + 2)
                root.reveal()
        }
    }

    onShownChanged: {
        revealTimer.stop()
        cancelRamp.stop()
        cancelAmount = 0
        revealed = false
        if (!shown) {
            // A fresh start the next time: no search text, first app selected, list at the top.
            searchField.text = ""
            appList.currentIndex = appList.count > 0 ? 0 : -1
            appList.positionViewAtBeginning()
        }
        if (shown) {
            flipsAtOpen = glassBackdrop.flips
            revealTimer.start()
            searchField.forceActiveFocus()
            // Again once the compositor has handed over the keyboard.
            focusTimer.restart()
        }
    }

    Timer {
        id: focusTimer
        interval: 60
        onTriggered: if (root.shown) searchField.forceActiveFocus()
    }
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

        // No drop shadow behind the panel: a shadow under the glass lowers how much of the
        // background shows through it (the shader cancels exactly that part), and the sharp
        // background then shows faintly through the glass.

        GlassPanel {
            id: glass

            // Placed in the backdrop's coordinates (whole pixels, as the glass needs).
            x: Math.round(launcher.x)
            y: Math.round(launcher.y)
            width: launcher.width
            height: launcher.height

            backdrop: glassBackdrop

            // Highlights are part of the glass (see GlassPanel.hlRect0): the search field, the
            // selected row and the hovered row. Rows are clipped to the visible list.
            hlRadius: Theme.radiusMedium
            cancelLeak: root.cancelAmount
            hlRect0: {
                launcher.x; launcher.y; glass.x; glass.y
                return glass.rectOf(searchField, false)
            }
            hlColor0: Qt.vector4d(Theme.surfaceAlt.r, Theme.surfaceAlt.g, Theme.surfaceAlt.b, 0.55)
            hlRect1: {
                appList.contentY; appList.currentIndex; launcher.x; launcher.y; glass.x; glass.y
                return glass.rectOf(appList.currentItem, true)
            }
            hlColor1: Qt.vector4d(Theme.surfaceAlt.r, Theme.surfaceAlt.g, Theme.surfaceAlt.b, 0.7)
            hlRect2: {
                appList.contentY; launcher.x; launcher.y; glass.x; glass.y
                return glass.rectOf(root.hoveredItem, true)
            }
            hlColor2: Qt.vector4d(Theme.surfaceAlt.r, Theme.surfaceAlt.g, Theme.surfaceAlt.b, 0.5)

            // `item` in this panel's coordinates; the list's rows are cut at the list's edges.
            function rectOf(item, inList) {
                if (!item) return Qt.vector4d(0, 0, 0, 0)
                const p = item.mapToItem(glass, 0, 0)
                let top = p.y
                let bottom = p.y + item.height
                if (inList) {
                    const l = appList.mapToItem(glass, 0, 0)
                    top = Math.max(top, l.y)
                    bottom = Math.min(bottom, l.y + appList.height)
                    if (bottom <= top) return Qt.vector4d(0, 0, 0, 0)
                }
                return Qt.vector4d(p.x, top, item.width, bottom - top)
            }

            style: GlassStyle {
                cornerRadius: Theme.radiusLarge
                edges: Qt.vector4d(1, 1, 1, 1)

                // The launcher's old background colour, over the blur: like an acrylic
                // taskbar, only more translucent. Raise tintStrength for more colour.
                tint: Theme.background
                tintStrength: 0.65
                // Fully frosted: any sharp background mixed into the glass shows as faint text.
                frost: 1.0
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
