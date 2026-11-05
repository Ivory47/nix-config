import QtQuick

// The look of one piece of glass. Every GlassPanel has its own, so different elements can have
// different glass over the same backdrop. (The blur *radius* belongs to the GlassBackdrop, since
// it is computed once for all the panels on it; `frost` below chooses how much of it each
// panel shows.)
QtObject {
    // How much of the blurred backdrop shows instead of the sharp one: 0..1.
    property real frost: 0.9

    // Rim geometry (logical pixels): width of the curved edge, and its relative height.
    property real bevel: 14
    property real thickness: 0.7
    property real cornerRadius: 0
    // Which edges are bevelled: left, top, right, bottom. The bar sits against the screen
    // edges, so only its lower edge curves.
    property vector4d edges: Qt.vector4d(0, 0, 0, 1)

    // Refraction.
    property real refraction: 1.0
    property real ior: 1.45
    // Chromatic dispersion: how far apart the indices of red and blue are.
    property real dispersion: 0.05

    // Tone.
    property color tint: "#1e1e2e"
    property real tintStrength: 0.35
    property real brightness: 0.02
    property real contrast: 1.04
    property real saturation: 1.2

    // Highlights on the rim, and where the light comes from (screen space, y down).
    property real shine: 0.6
    property vector2d lightDir: Qt.vector2d(-0.4, -0.9)

    // Pleamar's LENS_ALPHA: what the glass is drawn with. Below 1 so that the background can be
    // recovered from the next capture; the part that shows through is cancelled in the shader.
    // Raised from 0.88 (Pleamar's value) to show less of the background through the glass. The
    // cost: capture errors are amplified by 1 / (1 - alpha), 8.3x at 0.88, 12.5x at 0.92, and the
    // background cannot be recovered at all from 0.97 up.
    property real alpha: 0.92
    property real opacity: 1.0
}
