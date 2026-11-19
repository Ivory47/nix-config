import QtQuick
import qs.shared

// The brightness / volume indicator, simple: icon, bar, percent. The bar is the middle of it and the
// icon and the number sit at its two ends in slots of the same width, so that the bar is exactly in
// the middle of whatever this is put in. (The "simple" style of the balanced bar, and what the islands
// and notch layouts draw inside their pills.) The icon is centred on the optical middle (CenteredText),
// so that it lines up with the bar.
Item {
    id: root

    readonly property int spacing: OsdSource.slotGap
    readonly property int slot: OsdSource.slot
    readonly property bool volume: OsdSource.kind === "volume"
    readonly property real shown: OsdSource.muted && volume ? 0 : OsdSource.value
    readonly property string icon: volume
        ? (OsdSource.muted || OsdSource.value === 0 ? "󰝟" : OsdSource.value < 0.4 ? "󰕿" : OsdSource.value < 0.75 ? "󰖀" : "󰕾")
        : "󰃠"

    implicitWidth: track.width + 2 * (slot + spacing)
    implicitHeight: iconText.implicitHeight

    CenteredText {
        id: iconText
        anchors.right: track.left
        anchors.rightMargin: root.spacing
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        color: Theme.text
        font.pixelSize: 16
    }

    Rectangle {
        id: track
        anchors.centerIn: parent
        width: Theme.osdIndicatorWidth
        height: 6
        radius: 3
        color: Theme.surfaceAlt

        Rectangle {
            // The round end reads as a circle whose middle is the value: the end is `value` of the way
            // between the first and the last position of that middle, so 50% has the middle in the middle.
            width: root.shown <= 0 ? 0 : height + root.shown * (parent.width - height)
            height: parent.height
            radius: 3
            color: Theme.accent
            Behavior on width { NumberAnimation { duration: 90 } }
        }
    }

    CenteredText {
        anchors.left: track.right
        anchors.leftMargin: root.spacing
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(root.shown * 100)
        color: Theme.textMuted
        font.pixelSize: 12
    }
}
