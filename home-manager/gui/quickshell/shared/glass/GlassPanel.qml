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

    // Up to three rounded rectangles of colour drawn into the glass (x, y, width, height in
    // logical pixels of this panel; colour rgb and strength 0..1). Use these for highlights on
    // glass instead of translucent items over it: an item over the glass lowers how much of the
    // background shows through the stack, and below about 3% the background cannot be recovered
    // under it, so the blur is lost there (the sharp background shows).
    property vector4d hlRect0: Qt.vector4d(0, 0, 0, 0)
    property vector4d hlRect1: Qt.vector4d(0, 0, 0, 0)
    property vector4d hlRect2: Qt.vector4d(0, 0, 0, 0)
    property vector4d hlColor0: Qt.vector4d(0, 0, 0, 0)
    property vector4d hlColor1: Qt.vector4d(0, 0, 0, 0)
    property vector4d hlColor2: Qt.vector4d(0, 0, 0, 0)
    property real hlRadius: 6

    // 1: the part of the background that leaks through the glass is cancelled with the recovered
    // background (normal). 0: it is not. Use 0 while the recovered background may be out of date
    // (just after a surface was shown again): cancelling an old picture draws it inverted, while
    // not cancelling only lets a faint trace of the real background through.
    property real cancelLeak: 1

    fragmentShader: Qt.resolvedUrl("shaders/glass.frag.qsb")
}
