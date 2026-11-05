import QtQuick

// One opaque real pixel at the top left of the surface that says which version of the surface a
// capture was made from (see unmix.frag): its blue channel is 46 + 4 * (version % 8), red and
// green 30. Put it inside the backdrop's `composite`, above everything else, with the surface at
// the top left of the output. Dark and a few 255ths from the bar's tint: there is nothing else to
// see. Temporary form of the tag: it could instead be carried by pixels that are opaque anyway.
Rectangle {
    id: root

    required property var backdrop

    x: 0
    y: 0
    z: 1000000
    // Exactly one real pixel.
    width: 1 / backdrop.ratio
    height: 1 / backdrop.ratio
    antialiasing: false
    visible: backdrop.glassEnabled
    color: backdrop.tagColor
}
