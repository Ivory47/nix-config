import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import Glass.Native
import qs.shared

// One picture of the overlay's carousel (OverlayStage). `overlay` is the WallpaperOverlay (its list, the
// position, the look settings), `host` the stage the pictures glide in (the glass behind the picture sits in
// it, see below).
Item {
    id: card

    required property var overlay
    required property Item host
    required property int index


    readonly property real off: index - overlay.pos
    readonly property real a: Math.abs(off)
    readonly property bool near: a < 3
    readonly property var info: overlay.entries[index]

    visible: near && !!info
    width: overlay.cardW
    height: overlay.cardH
    // The neighbours sit behind the middle picture, smaller, and fade out.
    x: host.width / 2 - width / 2
       + (off < 0 ? -1 : 1) * overlay.cardW * (a <= 1 ? a * 0.74 : 0.74 + (a - 1) * 0.30)
    y: host.height / 2 - height / 2
    scale: Math.max(0.5, 1 - 0.32 * a)
    // (The neighbours stay quite opaque, then fade out towards the edges.)
    opacity: a <= 1 ? 1 - 0.08 * a : Math.max(0, 0.92 - 0.92 * (a - 1) / 1.9)
    // 0 for the middle picture, 1 from the first neighbour on.
    readonly property real side: Math.min(1, a)
    z: 100 - a * 10

    // The glass behind this picture. It is NOT a child of the card: the region it sends to the
    // compositor is its own position and size (it ignores an ancestor's scale, and is only
    // updated when its own geometry changes), so it sits in the stage and follows the card's
    // drawn rectangle, which changes at every step of the glide. It fades with the card, and
    // is not needed under the middle picture (opaque).
    LucentGlass {
        parent: card.host
        x: card.x + card.width * (1 - card.scale) / 2
        y: card.y + card.height * (1 - card.scale) / 2
        width: card.width * card.scale
        height: card.height * card.scale
        active: overlay.sideGlass && Theme.glass && Theme.compositorGlass && card.a > 0.15 && card.near
        blurRadius: overlay.sideBlur
        cornerRadius: overlay.cornerRadius * card.scale
        glassOpacity: card.opacity
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: overlay.cornerRadius
        color: Theme.surface

        // The picture is not drawn itself: the effect draws it, less saturated and flatter
        // the further it is from the middle.
        Image {
            id: picture
            anchors.fill: parent
            visible: false
            source: card.near && card.info ? "file://" + card.info.path : ""
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: Math.ceil(overlay.cardW * overlay.devicePixelRatio)
        }

        MultiEffect {
            anchors.fill: parent
            source: picture
            saturation: overlay.sideSaturation * card.side
            contrast: overlay.sideContrast * card.side
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: overlay.cornerRadius
        color: "transparent"
        border.width: card.a < 0.5 ? 2 : 1
        border.color: card.a < 0.5 ? OnImage.inkA(0.55) : OnImage.inkA(0.25)
    }

    // The one on the desktop now.
    Rectangle {
        visible: !!card.info && card.info.name === overlay.appliedName
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        width: nowLabel.implicitWidth + 20
        height: 24
        radius: 12
        color: Theme.accent

        CenteredText {
            id: nowLabel
            anchors.centerIn: parent
            text: "✓ Current"
            font.pixelSize: Theme.textSmall
            font.bold: true
            color: Theme.background
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (card.a >= 0.5)
                overlay.select(card.index)
            else
                overlay.applyNow()
        }
        onWheel: wheel => {
            overlay.onWheelDelta(wheel.angleDelta.x, wheel.angleDelta.y)
            wheel.accepted = true
        }
    }
}
