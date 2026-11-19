import QtQuick
import Quickshell
import qs.shared

// Layout "notch": one pill in the middle of the top edge and nothing else. It grows to what it
// shows: the workspaces, the clock and a few status icons at rest; the brightness / volume
// indicator for a moment; a new notification as a card; and, when it is clicked, a control centre
// (brightness, volume, what plays, the notification history).
BarWindow {
    id: win

    readonly property int maxH: 520

    // Nothing is reserved for a bar that is only a pill, except its row.
    implicitHeight: maxH + shadowRoom
    toastDuration: 4500

    onPanelOpenChanged: {
        if (panelOpen) {
            NotificationHistory.markRead()
            OsdSource.readBrightness()
        }
    }

    // "osd", "toast", "open" or "rest".
    readonly property string mode: panelOpen ? "open" : OsdSource.active ? "osd" : toast ? "toast" : "rest"

    mask: Region {
        Region { item: notch }
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
            id: notch
            y: win.gap
            width: (win.mode === "open" ? 400 : win.mode === "osd" ? osdBar.width + 24
                    : win.mode === "toast" ? 380 : restRow.width + 40)
            height: win.mode === "open" ? Math.min(win.maxH - win.gap * 2, win.pillH + 20 + centreCol.height + 16)
                  : win.mode === "toast" ? win.pillH + 34 : win.pillH
            x: Math.round((stage.width - width) / 2)
            strong: win.mode === "open" || win.mode === "toast"
            shadow: win.mode === "open" || win.mode === "toast"
            cornerRadius: win.mode === "open" || win.mode === "toast" ? Theme.radiusLarge + 6 : win.pillH / 2
            Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            Behavior on cornerRadius { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

            // The row at the top: at rest the whole pill, in the other modes its first line.
            Row {
                id: restRow
                y: (win.pillH - height) / 2
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16
                opacity: win.mode === "rest" || win.mode === "open" || win.mode === "toast" ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }

                Workspaces { anchors.verticalCenter: parent.verticalCenter }
                Clock {
                    anchors.verticalCenter: parent.verticalCenter
                    format: "HH:mm"
                }
                Wifi { anchors.verticalCenter: parent.verticalCenter }
                Battery { anchors.verticalCenter: parent.verticalCenter }
                NotificationBell {
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: win.panelOpen = !win.panelOpen
                }
            }

            // Clicking the pill's first line (not the icons) opens and closes the control centre.
            MouseArea {
                x: 0
                y: 0
                width: parent.width
                height: win.pillH
                z: -1
                cursorShape: Qt.PointingHandCursor
                onClicked: win.panelOpen = !win.panelOpen
            }

            OsdBar {
                id: osdBar
                y: (win.pillH - height) / 2
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: win.mode === "osd" ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }

            // A new notification: a line under the row.
            Column {
                visible: win.mode === "toast"
                x: 18
                y: win.pillH + 2
                width: parent.width - 36
                spacing: 1
                Text {
                    width: parent.width
                    text: win.toast ? (win.toast.app + (win.toast.app ? " · " : "") + win.toast.summary) : ""
                    elide: Text.ElideRight
                    color: Theme.text
                    font.pixelSize: 13
                    font.bold: true
                }
                Text {
                    width: parent.width
                    text: win.toast ? win.toast.body : ""
                    elide: Text.ElideRight
                    color: Theme.textMuted
                    font.pixelSize: 12
                }
            }

            // The control centre.
            Column {
                id: centreCol
                visible: opacity > 0.01
                opacity: win.mode === "open" ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
                x: 20
                y: win.pillH + 10
                width: parent.width - 40
                spacing: 12

                Row {
                    width: parent.width
                    spacing: 10
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22
                        text: "󰃠"
                        color: Theme.text
                        font.pixelSize: 16
                    }
                    BarSlider {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 32
                        value: OsdSource.brightness
                        onMoved: v => OsdSource.setBrightness(v)
                    }
                }
                Row {
                    width: parent.width
                    spacing: 10
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22
                        text: OsdSource.sinkMuted ? "󰝟" : "󰕾"
                        color: Theme.text
                        font.pixelSize: 16
                    }
                    BarSlider {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 32
                        value: OsdSource.sinkVolume
                        onMoved: v => OsdSource.setVolume(v)
                    }
                }
                Media {
                    maxWidth: parent.width
                }
                HistoryList {
                    width: parent.width
                    maxHeight: 280
                }
            }
        }
    }
}
