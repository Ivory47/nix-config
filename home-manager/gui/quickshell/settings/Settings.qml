import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.shared
import qs.shared.glass

// The settings app as a full-screen OVERLAY: a layer-shell popup over the desktop, which is blurred
// (a veil) while it is open. The window, the glass and the opening and closing are GlassPopup's, as
// for the launcher; what is inside is SettingsView.qml, which SettingsWindow.qml (the same settings
// as a normal window) uses too. Open it with `qs -c settings ipc call settings toggle` (the status
// bar's button does; the IPC handler is in shell.qml).
GlassPopup {
    id: root
    WlrLayershell.namespace: "settings"

    focusItem: view
    panelItem: panel

    // The whole desktop is blurred while this is open; its strength is its own setting. (The one
    // blurred picture is shared by the veil and the panel.)
    blurRadius: Math.max(0.1, Theme.scrimBlurRadius)

    onPopupClosed: view.reset()

    // The glass highlights the category row under the mouse (GlassListPanel reads popup.hoveredItem).
    Binding {
        target: root
        property: "hoveredItem"
        value: view.hoveredItem
    }

    // The desktop behind is blurred too, so that it is clear that only the settings can be used
    // now, and that a click anywhere else closes them.
    GlassScrim {
        popup: root
        hole: Qt.rect(panel.x, panel.y, panel.width, panel.height)
    }

    GlassListPanel {
        x: panel.x
        y: panel.y
        width: panel.width
        height: panel.height

        popup: root
        shadow: true
        // The less the desktop behind is blurred, the more tint: sharp text behind the panel
        // would show through it (from about 8 px of blur up, the panel's own tint is enough).
        tintStrength: Math.min(1, Theme.glassPanelTintStrength + 0.3 * (1 - Math.min(1, root.blurRadius / 8)))
        field: view.searchField
        listView: view.categoryList
    }

    Rectangle {
        id: panel

        // Centred, with the edges on whole pixels of the output (not only of the logical
        // grid): the veil's pieces (GlassScrim) meet the panel there, and an edge that falls
        // inside a pixel shows as a lighter line.
        readonly property real ratio: root.backdrop.ratio
        function snap(v) {
            return Math.round(v * ratio) / ratio
        }
        width: GlassGeometry.alignedSize(900, ratio)
        height: GlassGeometry.alignedSize(620, ratio)
        x: snap((root.width - width) / 2)
        y: snap((root.height - height) / 2)

        radius: Theme.radiusLarge
        color: "transparent"
        border.width: 1
        border.color: Theme.surfaceAlt

        // Swallows clicks on the panel itself.
        MouseArea {
            anchors.fill: parent
        }

        SettingsView {
            id: view
            anchors.fill: parent
            onCloseRequested: root.closePopup()
        }
    }
}
