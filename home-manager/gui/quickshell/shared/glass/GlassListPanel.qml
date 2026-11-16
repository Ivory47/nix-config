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
// (field background, row backgrounds), and a drop shadow must not go under it either (GlassShadow is drawn around it only).
//
// Put it in the popup's items, below the widgets, at the panel's position (x, y, width, height
// in whole pixels), with `popup`, `field` and `listView` set. The rows set `popup.hoveredItem`.
Item {
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
    // Opacity of the whole panel (1 = opaque glass; lower lets the live desktop show through).
    property real panelOpacity: 1.0

    // A soft drop shadow around the panel (Theme.popupShadow*), outside it only. Its opacity is
    // capped (GlassShadow.maxOpacity) so that over the settings' veil the stack still lets about
    // 3% of the background through.
    property bool shadow: false

    GlassShadow {
        z: -1
        visible: root.shadow && Theme.popupShadowOpacity > 0
        panelWidth: root.width
        panelHeight: root.height
        cornerRadius: Theme.radiusLarge
    }

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

    // The highlights: the field, the selected row, the hovered row.
    // (mapToItem is not tracked by bindings: the other values are listed so that they re-evaluate.)
    readonly property vector4d fieldRect: {
        root.x; root.y; root.width; root.height; field.width
        return rectOf(field, false)
    }
    readonly property vector4d selectedRect: {
        listView.contentY; listView.currentIndex; listView.count; listView.height; root.x; root.y; root.width; root.height
        return rectOf(listView.currentItem, true)
    }
    readonly property vector4d hoveredRect: {
        listView.contentY; listView.height; root.x; root.y; root.width; root.height
        return rectOf(popup.hoveredItem, true)
    }
    function highlight(strength) {
        return Qt.vector4d(highlightColor.r, highlightColor.g, highlightColor.b, strength)
    }

    GlassStyle {
        id: look
        cornerRadius: Theme.radiusLarge
        edges: Qt.vector4d(1, 1, 1, 1)

        // The old panel colour over the blur, translucent (raise tintStrength for more colour).
        tint: Theme.background
        tintStrength: root.tintStrength
        // Fully frosted: any sharp background mixed into the glass shows as faint text.
        frost: 1.0
        opacity: root.panelOpacity
    }

    // The glass, one of two: the shell's own, from captures ...
    GlassPanel {
        anchors.fill: parent
        visible: !root.popup.compositorGlass
        // (Its place in the backdrop is this item's, not its own inside this item.)
        originPx: Qt.vector2d(root.x * ratio, root.y * ratio)

        backdrop: root.popup.backdrop
        cancelLeak: root.popup.cancelAmount
        motionGate: 1
        hlRadius: Theme.radiusMedium
        hlRect0: root.fieldRect
        hlColor0: root.highlight(root.fieldStrength)
        hlRect1: root.selectedRect
        hlColor1: root.highlight(root.selectedStrength)
        hlRect2: root.hoveredRect
        hlColor2: root.highlight(root.hoveredStrength)
        style: look
    }

    // ... or the compositor's (GlassPopup.compositorGlass): the same look, drawn by the Lucent
    // plugin from what is behind the popup in the very frame it is shown in.
    LucentGlassPanel {
        anchors.fill: parent
        active: root.popup.compositorGlass

        blurRadius: root.popup.blurRadius
        maxTaps: Math.round(root.popup.backdrop.blurTaps)
        hlRadius: Theme.radiusMedium
        hlRect0: root.fieldRect
        hlColor0: root.highlight(root.fieldStrength)
        hlRect1: root.selectedRect
        hlColor1: root.highlight(root.selectedStrength)
        hlRect2: root.hoveredRect
        hlColor2: root.highlight(root.hoveredStrength)
        style: look
    }
}
