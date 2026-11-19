import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.shared
import qs.shared.glass

// Layout "islands": three glass pills with the desktop between them.
//   left: workspaces; centre: the clock (and what plays); right: the status icons and the bell.
// The centre pill morphs for the brightness / volume indicator and shows a new notification for a
// moment; the right pill grows downward into the notification history when the bell is clicked.
BarWindow {
    id: win



    onPanelOpenChanged: if (panelOpen) NotificationHistory.markRead()

    // What the centre pill shows: the indicator, a new notification, or the clock.
    // The newest one when this bar started is not news.
    toastDuration: 3500
    readonly property string centreMode: OsdSource.active ? "osd" : (toast ? "toast" : "clock")

    mask: Region {
        Region { item: left }
        Region { item: centre }
        Region { item: right }
        Region { item: catcher }
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
