import QtQuick
import QtQuick.Effects
import Quickshell
import qs.shared

// The base of the bar's menus in a popup window (classic, islands and notch layouts: the Wi-Fi, volume
// and power-profile menus): a transparent PopupWindow with the rounded card and its drop shadow. Set
// `implicitWidth` / `implicitHeight` and put the content inside; it becomes a child of `card`, which is
// inset by `cardMargin` (room for the shadow). A panel that should fill the whole window anchors with
// `anchors.margins: -menu.cardMargin`.
PopupWindow {
    id: menu

    property int cardMargin: 6
    readonly property alias card: card
    default property alias content: card.data

    color: "transparent"
    grabFocus: true

    Rectangle {
        id: card

        anchors {
            fill: parent
            margins: menu.cardMargin
        }
        color: Theme.background
        radius: 6

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.shadowColor
            shadowBlur: 0.5
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 3
        }
    }
}
