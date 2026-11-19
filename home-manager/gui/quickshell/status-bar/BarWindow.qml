import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.shared
import qs.shared.glass

// The window of a bar layout that draws its own pills (balanced, islands, notch): what they all have.
//  - the layer-shell window at the top edge (`barH` reserved, `panelH` more room below it for what grows
//    out of the bar and its shadow; `gap`, `pillH` for pill layouts);
//  - `panelOpen`: whether the bar has grown into a panel (history, menus, control centre); put a
//    BarCatcher in the stage so that a click anywhere else closes it;
//  - the toast: `toast` is the newest notification for `toastDuration` ms after it arrives (the one that
//    was newest when the bar started is not news).
// The layout adds `mask`, its pills and its own opening logic. (The classic bar is StatusBar.qml.)
PanelWindow {
    id: win

    WlrLayershell.namespace: "statusbar"
    anchors { top: true; left: true; right: true }

    readonly property int barH: GlassGeometry.alignedSize(Theme.statusBarHeight, win.devicePixelRatio)
    readonly property int gap: 6
    readonly property int pillH: barH - 2 * gap
    property int panelH: 420
    readonly property int shadowRoom: Math.ceil(Theme.notificationShadowBlur + Math.abs(Theme.notificationShadowOffset)) + 4
    property bool panelOpen: false

    implicitHeight: barH + panelH + shadowRoom
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: barH
    color: "transparent"

    property int toastDuration: 3500
    property int toastSeq: NotificationHistory.items.length > 0 ? NotificationHistory.items[0].seq : -1
    Component.onCompleted: toastSeq = toastSeq
    property var toast: null

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
        interval: win.toastDuration
        onTriggered: win.toast = null
    }
}
