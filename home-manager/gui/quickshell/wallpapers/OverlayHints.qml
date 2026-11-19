import QtQuick
import qs.shared

// What the keys are, on a dark plate (see the bar above).
Rectangle {
    required property var overlay

    opacity: overlay.shown && !overlay.filterPending ? 1 : 0
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 24
    width: hints.implicitWidth + 40
    height: 36
    radius: height / 2
    color: overlay.plateColor
    border.width: 1
    border.color: OnImage.inkA(0.14)

    CenteredText {
        id: hints
        anchors.centerIn: parent
        text: "\u2190 \u2192 wallpaper     \u21E7\u2190 \u21E7\u2192 colour     Tab list     F favourite     T tag     Esc close"
        color: OnImage.inkA(0.85)
        font.pixelSize: Theme.textSmall
    }
}
