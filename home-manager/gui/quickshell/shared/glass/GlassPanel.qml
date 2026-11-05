import QtQuick

// A piece of glass: draws the backdrop, bent by a bevelled rim, with dispersion, tint and
// highlights (glass.frag). Put it inside the backdrop's `composite`, below the content that
// has to stay sharp. Its x/y are taken as its place in the backdrop, so give it the composite
// as parent.
ShaderEffect {
    id: root

    required property var backdrop
    property GlassStyle style: GlassStyle {}

    // 0 = glass, 1 = show the recovered background, 2 = show the blurred one (for debugging)
    property int debugMode: 0

    readonly property real ratio: backdrop.ratio

    blending: true

    property variant sharp: backdrop.sharp
    property variant frosted: backdrop.frosted

    property vector2d sizePx: Qt.vector2d(width * ratio, height * ratio)
    property vector2d originPx: Qt.vector2d(x * ratio, y * ratio)
    property vector2d backdropPx: Qt.vector2d(backdrop.sizePx.width, backdrop.sizePx.height)
    property vector4d edges: style.edges
    property vector4d tint: Qt.vector4d(style.tint.r, style.tint.g, style.tint.b, style.tintStrength)
    property vector2d lightDir: style.lightDir
    property real pxRatio: ratio
    property real known: backdrop.ready ? 1 : 0
    property real cornerRadius: style.cornerRadius
    property real bevel: style.bevel
    property real thickness: style.thickness
    property real refraction: style.refraction
    property real ior: style.ior
    property real dispersion: style.dispersion
    property real frost: style.frost
    property real brightness: style.brightness
    property real contrast: style.contrast
    property real saturation: style.saturation
    property real shine: style.shine
    property real alpha: style.alpha
    property real glassOpacity: style.opacity
    property real debugView: debugMode

    fragmentShader: Qt.resolvedUrl("shaders/glass.frag.qsb")
}
