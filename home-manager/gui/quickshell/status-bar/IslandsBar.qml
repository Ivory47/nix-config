import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.shared
import qs.shared.glass

// Layout "islands": three glass pills with the desktop between them.
//   left: workspaces; centre: the clock (and what plays); right: the status icons and the bell.
// The centre pill morphs for the brightness / volume indicator and shows a new notification for a
// moment; the right pill grows downward into the notification history when the bell is clicked.
PanelWindow {
    id: win

    WlrLayershell.namespace: "statusbar"
    anchors { top: true; left: true; right: true }

    readonly property int barH: GlassGeometry.alignedSize(Theme.statusBarHeight, win.devicePixelRatio)
    readonly property int gap: 6
    readonly property int pillH: barH - 2 * gap
    readonly property int panelH: 420
    readonly property int shadowRoom: Math.ceil(Theme.notificationShadowBlur + Math.abs(Theme.notificationShadowOffset)) + 4
    property bool panelOpen: false

    implicitHeight: barH + panelH + shadowRoom
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: barH
    color: "transparent"

    onPanelOpenChanged: if (panelOpen) NotificationHistory.markRead()

    // What the centre pill shows: the indicator, a new notification, or the clock.
    // The newest one when this bar started is not news.
    property int toastSeq: NotificationHistory.items.length > 0 ? NotificationHistory.items[0].seq : -1
    Component.onCompleted: toastSeq = toastSeq
    property var toast: null
    readonly property string centreMode: OsdSource.active ? "osd" : (toast ? "toast" : "clock")

    Connections {
        target: NotificationHistory
        function onItemsChanged() {
            const first = NotificationHistory.items[0]
            if (!first)
                return
            if (first.seq !== win.toastSeq) {
                win.toastSeq = first.seq
                win.toast = first
                toastTimer.restart()
            }
        }
    }
    Timer {
        id: toastTimer
        interval: 3500
        onTriggered: win.toast = null
    }

    mask: Region {
        Region { item: left }
        Region { item: centre }
        Region { item: right }
        Region { item: catcher }
    }

    Item {
        id: stage
        anchors.fill: parent

        Item {
            id: catcher
            width: parent.width
            height: win.panelOpen ? parent.height : 0
            MouseArea {
                anchors.fill: parent
                onClicked: win.panelOpen = false
            }
        }

        BarPill {
            id: left
            x: win.gap + 4
            y: win.gap
            width: leftRow.width + 32
            height: win.pillH
            cornerRadius: height / 2
            Workspaces {
                id: leftRow
                anchors.centerIn: parent
            }
        }

        BarPill {
            id: centre
            y: win.gap
            width: (win.centreMode === "osd" ? osdBar.width : win.centreMode === "toast" ? toastRow.width : clockRow.width) + (win.centreMode === "osd" ? 24 : 36)
            x: Math.round((stage.width - width) / 2)
            height: win.pillH
            cornerRadius: height / 2
            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            Row {
                id: clockRow
                anchors.centerIn: parent
                spacing: 14
                opacity: win.centreMode === "clock" ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
                Clock {
                    format: "ddd d MMM  HH:mm"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Media {
                    maxWidth: 220
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            OsdBar {
                id: osdBar
                anchors.centerIn: parent
                opacity: win.centreMode === "osd" ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }
            Row {
                id: toastRow
                anchors.centerIn: parent
                spacing: 10
                opacity: win.centreMode === "toast" ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰂚"
                    color: Theme.accent
                    font.pixelSize: 15
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 360)
                    text: win.toast ? ((win.toast.app ? win.toast.app + ": " : "") + win.toast.summary) : ""
                    elide: Text.ElideRight
                    color: Theme.text
                    font.pixelSize: 13
                }
            }
        }

        BarPill {
            id: right
            y: win.gap
            width: Math.max(rightRow.width + 32, win.panelOpen ? 380 : 0)
            x: stage.width - width - win.gap - 4
            height: win.panelOpen ? Math.min(win.panelH - 8, win.pillH + history.implicitHeight + 28) : win.pillH
            cornerRadius: win.panelOpen ? Theme.radiusLarge + 4 : win.pillH / 2
            strong: win.panelOpen
            shadow: win.panelOpen
            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            Row {
                id: rightRow
                y: (win.pillH - height) / 2
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 15
                Wifi { anchors.verticalCenter: parent.verticalCenter }
                Audio { anchors.verticalCenter: parent.verticalCenter }
                Battery { anchors.verticalCenter: parent.verticalCenter }
                NotificationBell {
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: win.panelOpen = !win.panelOpen
                }
                SettingsButton { anchors.verticalCenter: parent.verticalCenter }
            }

            HistoryList {
                id: history
                x: 16
                y: win.pillH + 2
                width: parent.width - 32
                maxHeight: win.panelH - win.pillH - 40
                opacity: win.panelOpen ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 140 } }
            }
        }
    }
}
