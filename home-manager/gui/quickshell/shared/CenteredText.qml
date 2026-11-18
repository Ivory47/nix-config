import QtQuick

// Text that is centred on its OPTICAL middle, whatever the font. A plain `Text` centred by its box
// looks too high or too low with some fonts: the box is as tall as the font's line (ascent + descent
// + leading, and taller still when a symbol such as a star comes from a fallback font), and where the
// letters sit in that box depends on the font. Here the middle of the capital letters (the baseline
// minus half the cap height, from the font's own metrics) is put at the middle of this item, so a label
// in a button, chip or badge is centred the same with every font.
//
// Use it like a Text, where a Text was centred in a fixed-size box: `anchors.centerIn: parent` (or
// `anchors.fill: parent` with `horizontalAlignment: Text.AlignHCenter`, or `anchors.verticalCenter`
// in a Row). The item is as wide as the text and as tall as its line, so `implicitWidth` sizes a pill
// as before. For single symbols (arrows, stars, ×) use a plain Text: they have no cap height.
Item {
    id: root

    property alias text: label.text
    property alias color: label.color
    property alias font: label.font
    property alias elide: label.elide
    property alias wrapMode: label.wrapMode
    property alias maximumLineCount: label.maximumLineCount
    property alias horizontalAlignment: label.horizontalAlignment
    property alias textFormat: label.textFormat
    property alias truncated: label.truncated

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    FontMetrics {
        id: metrics
        font: label.font
    }

    Text {
        id: label
        width: root.width
        // baselineOffset is the real baseline of the first line (fallback fonts included).
        // (Not rounded: the renderer snaps the text to physical pixels, which is finer than logical ones
        // on a scaled output.)
        y: root.height / 2 - label.baselineOffset + metrics.capitalHeight / 2
    }
}
