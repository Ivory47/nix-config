import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.shared
import qs.shared.glass

// Layout "balanced": a full-width bar where every part has one job.
//   left: workspaces; centre: date and time (click: the notification history drops down); right: what
//   plays, wifi, volume, battery, settings.
// The brightness / volume indicator (Theme.barOsdStyle) is in the middle: "simple" (it takes the
// clock's place) or "bubble" (a small glass drop under the clock), or one that DOCKS into the bar: the
// bar barely changes, it gets a cut-out of exactly the indicator's shape (a bite from its bottom edge
// for "dock") and the indicator sits in it with a hair of
// space around it, so that the two almost fit together.
BarWindow {
    id: win

    // The panel under the bar: "history" (the notification centre), "wifi", "audio" or "power". It opens with a
    // small gap under the bar, under the clock or under the icon that was clicked.
    property string panelKind: "history"
    property real panelAnchorX: 0
    readonly property int panelGap: 6

    function togglePanel(kind, item) {
        if (panelOpen && panelKind === kind) {
            panelOpen = false
            return
        }
        panelKind = kind
        panelAnchorX = item ? stage.mapFromItem(item, item.width / 2, 0).x : stage.width / 2
        panelOpen = true
    }

    // The indicator's progress, 0..1 (animated).
    readonly property string style: Theme.barOsdStyle
    property real p: OsdSource.active ? 1 : 0
    Behavior on p { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    // The clock: the indicator takes its place ("simple" fades in over it). "dock" keeps the time where it
    // is and only hides the date (`dateFade`), as the bite is under the time.
    readonly property real clockFade: style === "simple" ? p : 0
    readonly property real dateFade: style === "dock" ? Math.min(1, p * 2.4) : 0

    // The docking styles: the indicator's rectangle (`pill`, in the window's pixels) and the bar's cut-out
    // around it (`cut`, in the bar's pixels: the pill grown by `slack`, with its corner radius `r`).
    // Nothing at all (no gap in the bar) until the indicator is really there.
    readonly property var dock: {
        const H = barH, cx = stage.width / 2
        const none = { pill: Qt.rect(0, 0, 0, 0), cut: Qt.rect(0, 0, 0, 0), r: 0 }
        if (p < 0.02)
            return none
        if (style === "dock") {
            // A small bite in the bottom edge, with the indicator tucked into it: most of it hangs below.
            const g = 3, wp = 30 + (OsdSource.barWidth + 20 - 30) * p, hp = 38 * Math.min(1, p * 1.15), depth = 14 * p
            const y = H - depth
            return { pill: Qt.rect(cx - wp / 2, y + g, wp, hp), cut: Qt.rect(cx - wp / 2 - g, y, wp + 2 * g, hp + 2 * g),
                     r: Math.min(hp, wp) / 2 + g }
        }
        return none
    }


    onPanelOpenChanged: if (panelOpen && panelKind === "history") NotificationHistory.markRead()
    onPanelKindChanged: if (panelOpen && panelKind === "history") NotificationHistory.markRead()

    // The panel closes when you move on: another workspace, another window (also what opening the
    // launcher does: it takes the focus), another screen. (Not while the password field has the keyboard
    // of the bar, nor for a moment after that, when the focus goes back.)
    property double keyboardChanged: 0
    readonly property bool takesKeyboard: panelOpen && panelKind === "wifi" && (panelContent.item?.wantsKeyboard ?? false)
    onTakesKeyboardChanged: keyboardChanged = Date.now()

    // (The focused window's address from the last "activewindowv2": that event also comes when the active
    // window only changes its title, which is not moving on.)
    property string lastActive: Hyprland.activeToplevel?.address ?? ""

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            let moved = false
            switch (event.name) {
            case "activewindowv2":
                moved = event.data !== win.lastActive
                win.lastActive = event.data
                break
            case "workspacev2":
            case "focusedmon":
            case "openwindow":
                moved = true
                break
            }
            if (moved && win.panelOpen && !win.takesKeyboard && Date.now() - win.keyboardChanged > 600)
                win.panelOpen = false
        }
    }

    // The Wi-Fi password field needs the keyboard (the bar normally takes none).
    WlrLayershell.keyboardFocus: takesKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Only the bar and the panel take the mouse; while the panel is open the whole window does, so that
    // a click anywhere else closes it.
    mask: Region {
        Region { item: bar }
        Region { item: catcher }
        Region { item: panel }
    }

    Item {
        id: stage
        anchors.fill: parent

        BarCatcher {
            id: catcher
            open: win.panelOpen
            onDismissed: win.panelOpen = false
        }

        BarPill {
            id: bar
            width: parent.width
            height: win.barH
            cornerRadius: 0
            edges: Qt.vector4d(0, 0, 0, 1)
            outline: false
            bottomLine: false
            drawFallback: false
            // The cut-out of the docking styles (the glass has a hole there; BarDecor draws the rest).
            holeRect: Qt.vector4d(win.dock.cut.x, win.dock.cut.y, win.dock.cut.width, win.dock.cut.height)
            holeRadius: win.dock.r

            BarDecor {
                cut: win.dock.cut
                r: win.dock.r
                glassWanted: bar.glassWanted
            }

            // left
            Row {
                anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                spacing: 14
                Workspaces {
                    anchors.verticalCenter: parent.verticalCenter
                    // (Measured: the dots sat a physical pixel below the clock and the icons.)
                    anchors.verticalCenterOffset: -0.75
                }
            }

            // centre: date and time, and the unread notifications (BalancedCentre). One click target: it
            // opens and closes the notification history.
            BalancedCentre {
                id: centreBlock
                anchors.centerIn: parent
                open: win.panelOpen && win.panelKind === "history"
                dateFade: win.dateFade
                opacity: 1 - win.clockFade
                enabled: win.clockFade < 0.5
                onClicked: win.togglePanel("history", centreBlock)
            }

            // right
            Row {
                id: cluster
                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                spacing: 15

                Media { anchors.verticalCenter: parent.verticalCenter }
                Wifi {
                    id: wifiWidget
                    embedded: true
                    anchors.verticalCenter: parent.verticalCenter
                    onToggled: win.togglePanel("wifi", wifiWidget)
                }
                Audio {
                    id: audioWidget
                    embedded: true
                    anchors.verticalCenter: parent.verticalCenter
                    onToggled: win.togglePanel("audio", audioWidget)
                }
                Battery {
                    id: batteryWidget
                    embedded: true
                    anchors.verticalCenter: parent.verticalCenter
                    onToggled: win.togglePanel("power", batteryWidget)
                }
                SettingsButton { anchors.verticalCenter: parent.verticalCenter }
            }
        }

        // The panel: grows down under the bar (with a small gap), under the clock or the icon that opened it.
        BarPill {
            id: panel
            readonly property real wantW: win.panelKind === "wifi" ? 316 : win.panelKind === "audio" ? 40 : win.panelKind === "power" ? 196 : 380
            readonly property real wantH: win.panelKind === "wifi" ? 336
                : win.panelKind === "audio" ? 140 : win.panelKind === "power" ? 176 : Math.min(win.panelH - 8, history.implicitHeight + 32)
            x: Math.max(8, Math.min(stage.width - width - 8, win.panelAnchorX - width / 2))
            y: win.barH + win.panelGap
            width: wantW
            height: win.panelOpen ? wantH : 0
            visible: height > 1
            cornerRadius: Theme.radiusLarge
            strong: true
            shadow: true
            Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            // History (always there for its height; shown for the notification centre).
            HistoryList {
                id: history
                x: 16
                y: 16
                width: 380 - 32
                maxHeight: win.panelH - 48
                visible: win.panelKind === "history"
            }

            // The menus of the Wi-Fi and volume icons.
            Loader {
                id: panelContent
                // (The volume menu is slim: its own margins are all it needs.)
                readonly property real inset: win.panelKind === "audio" ? 0 : 8
                x: inset
                y: inset
                width: parent.width - 2 * inset
                height: parent.height - 2 * inset
                active: (win.panelOpen || panel.height > 1) && win.panelKind !== "history"
                sourceComponent: win.panelKind === "wifi" ? wifiC : win.panelKind === "power" ? powerC : audioC
            }
        }

        Component {
            id: wifiC
            WifiPanel {
                onCloseRequested: win.panelOpen = false
            }
        }
        Component {
            id: powerC
            PowerPanel {
                onCloseRequested: win.panelOpen = false
            }
        }
        Component {
            id: audioC
            AudioPanel { compact: true }
        }

        // The brightness / volume indicator (Theme.barOsdStyle), over everything in the window.
        Loader {
            id: osd
            anchors.fill: parent
            z: 10
            sourceComponent: {
                switch (win.style) {
                case "bubble": return bubbleC
                case "dock": return dockC
                default: return simpleC
                }
            }
        }

        // simple: the indicator fades in where the clock was.
        Component {
            id: simpleC
            Item {
                anchors.fill: parent
                OsdBar {
                    anchors.horizontalCenter: parent.horizontalCenter
                    // (Measured: 1 physical pixel below the clock and the icons without the - 0.75.)
                    y: (win.barH - height) / 2 - 0.75
                    opacity: win.p
                }
            }
        }

        // dock: a glass pill of its own, in the bar's cut-out. (In an Item that fills the
        // Loader: a Loader resizes what it loads, which would override the pill's own size.)
        Component {
            id: dockC
            Item {
                anchors.fill: parent
                BarPill {
                    x: win.dock.pill.x
                    y: win.dock.pill.y
                    width: win.dock.pill.width
                    height: win.dock.pill.height
                    cornerRadius: Math.min(width, height) / 2
                    visible: win.p > 0.03 && width > 6 && height > 6
                    strong: true
                    shadow: true

                    OsdBar {
                        anchors.centerIn: parent
                        // (Measured: with the -0.75 of the simple style it sat 1 to 1.7 physical px above the
                        // pill's middle; this is centred in its own pill.)
                        opacity: Math.max(0, (win.p - 0.55) / 0.45)
                    }
                }
            }
        }

        // bubble: centred on the clock block.
        Component { id: bubbleC; OsdBubble { barH: win.barH; centreX: centreBlock.x + centreBlock.width / 2 } }
    }
}
