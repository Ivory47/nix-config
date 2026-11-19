pragma Singleton

import QtQuick

// The colours that sit on top of the wallpaper pictures in the overlay (the plates, the text and outlines over
// the images). Deliberately NOT themed: the pictures are arbitrary and mostly dark under the plates, so
// these stay white and black whatever the theme's text colour is. inkA(a) / shadeA(a): white / black at
// opacity a.
QtObject {
    readonly property color ink: "white"
    readonly property color shade: "black"

    function inkA(a) { return Qt.rgba(1, 1, 1, a) }
    function shadeA(a) { return Qt.rgba(0, 0, 0, a) }
}
