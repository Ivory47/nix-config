import QtQuick
import qs.shared

// A blurred, tinted veil over the whole popup surface (the desktop behind a popup) except `hole`,
// where the popup's own panel sits: one glass panel over the surface with a rounded hole cut out
// of it (GlassPanel.holeRect, in the shader). Not a second panel under the popup's: glass over
// glass would leave less than 3% of the background showing through the stack, and the
// background cannot be recovered under that (see GlassListPanel). It has no bevel or
// refraction. It does not take the mouse: clicks go to whatever is below it.
//
//  - How much it blurs follows `popup.blurRadius`: below about 3 the blurred picture is mixed
//    with the sharp one (the blur pass always leaves a little softness, even at 0), so 0 shows
//    the desktop sharp.
//  - With the glass off (Theme.glass) there is no capture and so no blur: the veil is then a
//    plain translucent tint over the desktop (the glass panel would draw an opaque one).
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

    x: 0
    y: 0
    width: parent.width
    height: parent.height

    GlassPanel {
        anchors.fill: parent
        visible: root.popup.backdrop.glassEnabled

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

    // Glass off: nothing to blur, so only a tint. (No glass here, so translucent is fine; the
    // panel above it is opaque in this mode.)
    Rectangle {
        anchors.fill: parent
        visible: !root.popup.backdrop.glassEnabled
        color: Qt.alpha(Theme.background, 0.45)
    }
}
