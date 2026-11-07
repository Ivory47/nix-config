import QtQuick
import QtQuick.Shapes
import qs.shared

// A blurred, tinted veil over the whole popup surface (the desktop behind a popup) except `hole`,
// where the popup's own panel sits: one glass panel over the surface with a rounded hole cut out
// of it (GlassPanel.holeRect, in the shader). Not a second panel under the popup's: glass over
// glass would leave less than 3% of the background showing through the stack, and the
// background cannot be recovered under that (see GlassListPanel). It has no bevel or
// refraction. It does not take the mouse: clicks go to whatever is below it.
//
//  - How much it blurs follows `popup.blurRadius`: below about 3 the blurred picture is mixed
//    with the sharp one (the blur pass always leaves a little softness, even at 0).
//  - Below `plainBelow` (3 px) it is not glass at all but a plain translucent tint over the
//    desktop, which then shows exactly as it is. The glass cannot show the desktop sharp: it
//    rebuilds the picture by taking its own layer (92% opaque, so 8% shows through) out of the
//    screenshot, which multiplies the screenshot's 8-bit rounding by about 12, and smooth
//    gradients (the status bar's blur is one) turn into flat steps. A blurred veil smooths that
//    out again, a sharp one cannot.
//  - With the glass off (Theme.glass) there is no capture and so no blur: the same plain tint
//    (the glass panel would draw an opaque one).
//
// Put it in the popup's items below the panel; `hole` is the panel's rectangle in the surface's
// coordinates (its corner radius is `holeRadius`, Theme.radiusLarge by default).
Item {
    id: root

    required property var popup
    required property rect hole
    property real holeRadius: Theme.radiusLarge

    // How much of the tint colour is mixed in (the panels use 0.65, the status bar 0.35).
    property real tintStrength: 0.3

    // Below this blur radius (px) the veil is the plain tint, and how opaque that is.
    property real plainBelow: 3
    property real plainOpacity: 0.35
    readonly property bool plain: !popup.backdrop.glassEnabled || popup.blurRadius < plainBelow

    x: 0
    y: 0
    width: parent.width
    height: parent.height

    GlassPanel {
        anchors.fill: parent
        visible: !root.plain

        backdrop: root.popup.backdrop
        cancelLeak: root.popup.cancelAmount
        holeRect: Qt.vector4d(root.hole.x, root.hole.y, root.hole.width, root.hole.height)
        holeRadius: root.holeRadius

        style: GlassStyle {
            cornerRadius: 0
            edges: Qt.vector4d(0, 0, 0, 0)
            tint: Theme.background
            tintStrength: root.tintStrength
            frost: Math.max(0, Math.min(1, root.popup.blurRadius / 3))
        }
    }

    // The plain tint: the whole surface except the hole. One shape with the hole as a second
    // outline (odd-even fill), so that nothing overlaps the panel (no glass over glass under it)
    // and the corners follow the panel's rounded ones. (No glass here, so translucent is fine.)
    Shape {
        anchors.fill: parent
        visible: root.plain
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: Qt.alpha(Theme.background, root.plainOpacity)
            strokeColor: "transparent"
            fillRule: ShapePath.OddEvenFill

            // The surface.
            startX: 0
            startY: 0
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.height }
            PathLine { x: 0; y: root.height }
            PathLine { x: 0; y: 0 }

            // The hole: a rounded rectangle.
            PathMove { x: root.hole.x + root.holeRadius; y: root.hole.y }
            PathLine { x: root.hole.x + root.hole.width - root.holeRadius; y: root.hole.y }
            PathArc {
                x: root.hole.x + root.hole.width; y: root.hole.y + root.holeRadius
                radiusX: root.holeRadius; radiusY: root.holeRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: root.hole.x + root.hole.width; y: root.hole.y + root.hole.height - root.holeRadius }
            PathArc {
                x: root.hole.x + root.hole.width - root.holeRadius; y: root.hole.y + root.hole.height
                radiusX: root.holeRadius; radiusY: root.holeRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: root.hole.x + root.holeRadius; y: root.hole.y + root.hole.height }
            PathArc {
                x: root.hole.x; y: root.hole.y + root.hole.height - root.holeRadius
                radiusX: root.holeRadius; radiusY: root.holeRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: root.hole.x; y: root.hole.y + root.holeRadius }
            PathArc {
                x: root.hole.x + root.holeRadius; y: root.hole.y
                radiusX: root.holeRadius; radiusY: root.holeRadius
                direction: PathArc.Clockwise
            }
        }
    }
}
