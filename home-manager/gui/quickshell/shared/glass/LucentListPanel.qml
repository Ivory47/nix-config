import QtQuick
import qs.shared

// The glass of a NORMAL WINDOW (FloatingWindow) with a search field above a list or grid: the
// counterpart of GlassListPanel for compositor glass only (see GLASS-WINDOWS.md). It is a
// LucentGlassPanel, so it fills the item it is anchored to, and it draws the highlights of the
// search field, the selected item and the item under the mouse through the glass (hlRect0..2).
// There is no captured glass, no backdrop, no tag pixel and no shadow here: the compositor draws the
// glass, and Hyprland draws the window's border and shadow.
//
// Put it first in the window's content (below the widgets), `anchors.fill: parent`, give it `field`
// and `listView`, and let the rows set `hoveredItem`. The widgets above it must be transparent where
// the highlights are (field background, row backgrounds). Use it only while `available` is true;
// show a plain panel otherwise.
LucentGlassPanel {
    id: root

    // The search field and the ListView / GridView whose current item is highlighted.
    required property Item field
    required property Item listView
    // The row or card under the mouse, if any.
    property Item hoveredItem: null

    // The blur's cost cap: the same as the popups' (GlassBackdrop.blurTaps), from the blur radius.
    maxTaps: Math.round(Math.max(4, Theme.blurMaxTaps * Math.pow(Math.min(1, 14 / Math.max(0.1, blurRadius)), Theme.blurTapsFalloff)))

    property color highlightColor: Theme.surfaceAlt
    property real fieldStrength: 0.55
    property real selectedStrength: 0.7
    property real hoveredStrength: 0.5

    // `item` in this glass's coordinates; items of the list are cut at the list's edges.
    function rectOf(item, inList) {
        if (!item) return Qt.vector4d(0, 0, 0, 0)
        // (A grid reflows its cells when the window is resized: reading the item's own position makes
        // the binding follow it. mapToItem alone is not tracked.)
        item.x; item.y; item.width; item.height
        const p = item.mapToItem(root, 0, 0)
        let top = p.y
        let bottom = p.y + item.height
        if (inList) {
            listView.contentX; listView.contentY; listView.width
            const l = listView.mapToItem(root, 0, 0)
            top = Math.max(top, l.y)
            bottom = Math.min(bottom, l.y + listView.height)
            if (bottom <= top) return Qt.vector4d(0, 0, 0, 0)
        }
        return Qt.vector4d(p.x, top, item.width, bottom - top)
    }

    // (mapToItem is not tracked by bindings: the other values are listed so that they re-evaluate.)
    readonly property vector4d fieldRect: {
        root.x; root.y; root.width; root.height; field.width; field.x; field.y
        return rectOf(field, false)
    }
    readonly property vector4d selectedRect: {
        listView.contentY; listView.currentIndex; listView.count; listView.height; listView.x; listView.y
        root.x; root.y; root.width; root.height
        return rectOf(listView.currentItem, true)
    }
    readonly property vector4d hoveredRect: {
        listView.contentY; listView.height; listView.x; listView.y; root.x; root.y; root.width; root.height
        return rectOf(hoveredItem, true)
    }
    function highlight(strength) {
        return Qt.vector4d(highlightColor.r, highlightColor.g, highlightColor.b, strength)
    }

    hlRadius: Theme.radiusMedium
    hlRect0: fieldRect
    hlColor0: highlight(fieldStrength)
    hlRect1: selectedRect
    hlColor1: highlight(selectedStrength)
    hlRect2: hoveredRect
    hlColor2: highlight(hoveredStrength)

    // The look of the panels (Settings › Theme › Panels), with the rounding of a Hyprland window
    // (decoration.rounding): the window rounds its own content only, the glass rounds itself.
    // Override `style` for another look.
    style: PanelGlassStyle {
        cornerRadius: 6
        edges: Qt.vector4d(1, 1, 1, 1)
        tint: Theme.background
    }
}
