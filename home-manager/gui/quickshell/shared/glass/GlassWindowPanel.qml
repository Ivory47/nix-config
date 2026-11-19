import QtQuick
import qs.shared

// The background of a GlassWindow with a search field above a list or grid: the compositor's glass
// (LucentListPanel) and, when there is none (no Lucent plugin, or Theme.glass / Theme.compositorGlass
// off), a plain opaque panel. `glassOn` tells which, so that the content can draw its own highlights
// when it is false. Make it the first item of the window's content, `anchors.fill: parent`.
Item {
    id: root

    required property Item field
    required property Item listView
    property Item hoveredItem: null

    readonly property bool glassOn: glass.active && glass.available

    Rectangle {
        anchors.fill: parent
        visible: !root.glassOn
        color: Theme.background
        radius: 6   // = decoration.rounding
    }

    // Hyprland draws the window's border and shadow.
    LucentListPanel {
        id: glass
        anchors.fill: parent
        active: Theme.glass && Theme.compositorGlass
        blurRadius: Theme.glassBlurRadius
        field: root.field
        listView: root.listView
        hoveredItem: root.hoveredItem
    }
}
