import QtQuick
import Quickshell
import qs.shared
import qs.shared.glass

// The settings app as a NORMAL WINDOW (a Quickshell FloatingWindow, tiled or floated by Hyprland like
// any other window) with the compositor's glass behind it: see shared/glass/GLASS-WINDOWS.md. The
// same pages as the overlay (SettingsView.qml), but no veil over the desktop, no captured glass and
// no shadow of its own (Hyprland draws the border and the shadow). Without the Lucent plugin, or
// with Theme.glass / Theme.compositorGlass off, it is an opaque panel with plain highlights.
//
// Open and close it with `shown` (IPC `toggleWindow` / `showWindow` / `hide`, in shell.qml). The
// window and its content exist only while it is open, so it starts fresh every time. Closing the
// window from the compositor (Super+C) sets `shown` false through `onClosed`.
GlassWindow {
    id: win

    title: "Settings"
    implicitWidth: 900
    implicitHeight: 620
    minimumSize: Qt.size(700, 460)

    focusItem: loader.item ? loader.item.view : null

    Loader {
        id: loader
        anchors.fill: parent
        active: win.shown
        onLoaded: win.focusSoon()

        sourceComponent: Item {
            property alias view: view

            GlassWindowPanel {
                id: glass
                anchors.fill: parent
                field: view.searchField
                listView: view.categoryList
                hoveredItem: view.hoveredItem
            }

            SettingsView {
                id: view
                anchors.fill: parent
                glassOn: glass.glassOn
                onCloseRequested: win.closeWindow()
            }
        }
    }
}
