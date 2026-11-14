import QtQuick
import qs.shared

// A soft drop shadow around a rounded rectangle, like the one under Windows 11 menus. It is
// drawn only outside the panel (shadow.frag): glass must have nothing under it, see
// GlassListPanel. Give it the panel's size; it extends over the panel by `extent` on every side.
// Set Theme.popupShadowOpacity to 0 to turn it off.
ShaderEffect {
    id: root

    property real panelWidth: 0
    property real panelHeight: 0
    property real cornerRadius: Theme.radiusLarge

    // Over the settings' veil (alpha 0.92) a shadow of 0.6 still lets 3.2% of the background
    // through, about the least that can be recovered, so the opacity is capped there.
    readonly property real maxOpacity: 0.6
    readonly property real blurSize: Math.max(0.1, Theme.popupShadowBlur)
    readonly property real offsetY: Theme.popupShadowOffset
    // Room for the fade and the offset.
    readonly property real extent: Math.ceil(blurSize + Math.abs(offsetY)) + 2

    visible: Theme.popupShadowOpacity > 0
    blending: true
    x: -extent
    y: -extent
    width: panelWidth + 2 * extent
    height: panelHeight + 2 * extent

    property vector2d itemSize: Qt.vector2d(width, height)
    property vector2d offset: Qt.vector2d(0, offsetY)
    property vector4d color: Qt.vector4d(0, 0, 0, Math.min(Theme.popupShadowOpacity, maxOpacity))
    property real margin: extent
    property real radius: cornerRadius
    property real blur: blurSize

    fragmentShader: Qt.resolvedUrl("shaders/shadow.frag.qsb")
}
