import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.shared

// The window of the notification cards: a transparent layer surface along the right edge under the
// bar (Overlay layer, so it is over fullscreen windows too), as wide as a card and as tall as the
// screen. Only the cards take the mouse (`mask`), the rest of the surface lets clicks through.
// Newest on top; at most `maxShown` are visible, the others wait and show when there is room.
//
// The glass of every card is a LucentGlass in `stage` (see NotificationCard.qml), not inside the
// card: the plugin only learns of a region when the glass item itself moves or resizes.
PanelWindow {
    id: win

    readonly property int maxShown: 4
    readonly property int count: cards.count
    // The screen of the focused monitor, picked while no card is showing (a window that changes
    // screen is recreated, which must not happen under a card's glass).
    property var chosenScreen: Quickshell.screens[0]
    screen: chosenScreen

    WlrLayershell.namespace: "notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    color: "transparent"

    anchors {
        top: true
        right: true
        bottom: true
    }
    margins {
        top: Theme.statusBarHeight + Theme.spacingMedium
        right: Theme.spacingMedium
    }
    implicitWidth: 380

    // Only where the cards are.
    mask: Region {
        item: column
    }

    // notification id -> Notification (a ListModel cannot hold the objects).
    property var registry: ({})

    ListModel {
        id: cards
    }

    function add(n) {
        if (cards.count === 0) {
            const focused = Hyprland.focusedMonitor?.name
            const s = Quickshell.screens.find(s => s.name === focused)
            if (s && s !== chosenScreen)
                chosenScreen = s
        }
        registry[n.id] = n
        cards.insert(0, { nid: n.id })
    }

    function removeCard(nid) {
        for (let i = 0; i < cards.count; i++) {
            if (cards.get(i).nid === nid) {
                cards.remove(i)
                break
            }
        }
        delete registry[nid]
    }

    function dismissAll() {
        for (const id in registry)
            registry[id].dismiss()
    }

    Item {
        id: stage
        anchors.fill: parent

        Column {
            id: column
            width: parent.width

            Repeater {
                model: cards

                NotificationCard {
                    required property int nid
                    required property int index
                    width: column.width
                    glassParent: stage
                    listItem: column
                    notification: win.registry[nid]
                    // Only the newest ones are visible; the others wait their turn.
                    slot: index < win.maxShown
                    onFinished: win.removeCard(nid)
                }
            }
        }
    }
}
