import QtQuick
import Glass.Native
import qs.shared
import qs.shared.glass

// A piece of the new bar layouts: compositor glass (the Lucent plugin) with a border, or an opaque
// panel without the plugin. Put it directly in the window's top item and move/resize it there (x, y,
// width, height may animate): the plugin takes a glass's region from the glass item's own position
// and size, so the glass is bound to this item's geometry (same reason as NotificationCard).
// Children go in `content` (clipped to the pill).
Item {
    id: pill

    property real cornerRadius: Theme.radiusLarge
    // Which edges are bevelled: left, top, right, bottom.
    property vector4d edges: Qt.vector4d(1, 1, 1, 1)
    // The outline (a full one; `bottomLine` instead for a bar against the screen edges).
    property bool outline: true
    property bool bottomLine: false
    // A bigger piece with text on it (a panel, the history): tinted like the popups, so that what is
    // behind does not disturb the text.
    property bool strong: false
    // A drop shadow (Theme.notificationShadow*, outside the pill only): for the panels.
    property bool shadow: false
    // False: draws nothing of its own (no glass, panel, outline or shadow), only holds its children.
    property bool drawBackground: true
    // A rounded hole in the glass (x, y, width, height in this pill's pixels; radius): what the indicator
    // docks into. The panel fill and outline of a pill with a hole are drawn by the user (BarDecor), so
    // `drawFallback` is off for it.
    property vector4d holeRect: Qt.vector4d(0, 0, 0, 0)
    property real holeRadius: 0
    property bool drawFallback: true
    default property alias content: body.data
    readonly property bool glassWanted: glass.wanted

    LucentGlassPanel {
        id: glass
        readonly property bool wanted: Theme.glass && Theme.compositorGlass && available
        parent: pill.parent
        x: pill.x
        y: pill.y
        width: Math.max(0, pill.width)
        height: Math.max(0, pill.height)
        active: wanted && pill.visible && pill.drawBackground && width > 8 && height > 8
        glassOpacity: pill.opacity
        blurRadius: Theme.glassBlurRadius
        holeRect: pill.holeRect
        holeRadius: pill.holeRadius
        maxTaps: Math.round(Math.max(4, Theme.blurMaxTaps * Math.pow(Math.min(1, 14 / Math.max(0.1, blurRadius)), Theme.blurTapsFalloff)))
        style: BarGlassStyle {
            cornerRadius: pill.cornerRadius
            edges: pill.edges
            tint: pill.strong ? Theme.background : Theme.glassBarTint
            tintStrength: pill.strong ? Theme.glassPanelTintStrength : Theme.glassBarTintStrength
        }
    }

    Item {
        parent: pill.parent
        z: -1
        x: pill.x
        y: pill.y
        width: pill.width
        height: pill.height
        opacity: pill.opacity
        visible: pill.shadow && pill.visible && pill.drawBackground && pill.height > 8
        GlassShadow {
            panelWidth: parent.width
            panelHeight: parent.height
            cornerRadius: pill.cornerRadius
            strength: Theme.notificationShadowOpacity
            softness: Theme.notificationShadowBlur
            drop: Theme.notificationShadowOffset
        }
    }

    // No compositor glass: an opaque panel.
    Rectangle {
        anchors.fill: parent
        visible: !glass.wanted && pill.drawBackground && pill.drawFallback
        radius: pill.cornerRadius
        color: Theme.background
    }

    Item {
        id: body
        anchors.fill: parent
        clip: true
    }

    Rectangle {
        anchors.fill: parent
        visible: pill.outline && pill.drawBackground
        radius: pill.cornerRadius
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(Theme.barBorderColor, Theme.barBorderOpacity)
    }

    Rectangle {
        visible: pill.bottomLine && pill.drawBackground
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: Qt.alpha(Theme.barBorderColor, Theme.barBorderOpacity)
    }
}
