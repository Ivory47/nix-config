import QtQuick
import qs.shared

// The glass of a popup with a search field above a list (app launcher, clipboard history): the
// look of both, and the highlights of the search field, the selected row and the row under the
// mouse, drawn by the glass itself.
//
// Highlights are drawn here, in the glass shader, and not as translucent items over the glass: an
// item over the glass lowers how much of the background shows through the stack, and where less
// than about 3% shows through the background cannot be recovered, so the sharp background shows
// there (see GlassPanel.hlRect0). The popup's own items must therefore be transparent over it
// (field background, row backgrounds), and there is no drop shadow under it either.
//
// Put it in the popup's items, below the widgets, at the panel's position (x, y, width, height
// in whole pixels), with `popup`, `field` and `listView` set. The rows set `popup.hoveredItem`.
GlassPanel {
    id: root

    required property var popup
    // The search field and the ListView (`listView`) whose current row is highlighted.
    required property Item field
    required property Item listView

    // Highlight colour, and strengths (0..1) for the field, the selected row, the hovered row.
    property color highlightColor: Theme.surfaceAlt
    property real fieldStrength: 0.55
    property real selectedStrength: 0.7
    property real hoveredStrength: 0.5
    // How much of the tint colour is mixed into the glass (more hides more of what is behind).
    property real tintStrength: 0.65

    backdrop: popup.backdrop
    cancelLeak: popup.cancelAmount
    hlRadius: Theme.radiusMedium

    // `item` in this panel's coordinates; the list's rows are cut at the list's edges.
    function rectOf(item, inList) {
        if (!item) return Qt.vector4d(0, 0, 0, 0)
        const p = item.mapToItem(root, 0, 0)
        let top = p.y
        let bottom = p.y + item.height
        if (inList) {
            const l = listView.mapToItem(root, 0, 0)
            top = Math.max(top, l.y)
            bottom = Math.min(bottom, l.y + listView.height)
            if (bottom <= top) return Qt.vector4d(0, 0, 0, 0)
        }
        return Qt.vector4d(p.x, top, item.width, bottom - top)
    }

    // (mapToItem is not tracked by bindings: the other values are listed so that they re-evaluate.)
    hlRect0: {
        root.x; root.y; root.width; root.height; field.width
        return rectOf(field, false)
    }
    hlColor0: Qt.vector4d(highlightColor.r, highlightColor.g, highlightColor.b, fieldStrength)
    hlRect1: {
        listView.contentY; listView.currentIndex; listView.count; listView.height; root.x; root.y; root.width; root.height
        return rectOf(listView.currentItem, true)
    }
    hlColor1: Qt.vector4d(highlightColor.r, highlightColor.g, highlightColor.b, selectedStrength)
    hlRect2: {
        listView.contentY; listView.height; root.x; root.y; root.width; root.height
        return rectOf(popup.hoveredItem, true)
    }
    hlColor2: Qt.vector4d(highlightColor.r, highlightColor.g, highlightColor.b, hoveredStrength)

    style: GlassStyle {
        cornerRadius: Theme.radiusLarge
        edges: Qt.vector4d(1, 1, 1, 1)

        // The old panel colour over the blur, translucent (raise tintStrength for more colour).
        tint: Theme.background
        tintStrength: root.tintStrength
        // Fully frosted: any sharp background mixed into the glass shows as faint text.
        frost: 1.0
    }
}
