import QtQuick
import qs.shared

// Indicator style "bubble": a glass drop that grows out of the bottom of the bar, in the middle, with
// a bounce, holding a big icon, a thick bar with a bright tip and the number. It shrinks back into
// the bar. (Put in the window's top item; `barH` is the bar's height.)
Item {
    id: root

    property real barH: 50
    // The x the drop is centred on (the clock's middle).
    property real centreX: width / 2
    readonly property bool on: OsdSource.active
    readonly property bool volume: OsdSource.kind === "volume"
    readonly property real shown: OsdSource.muted && volume ? 0 : OsdSource.value
    readonly property string icon: volume
        ? (OsdSource.muted || OsdSource.value === 0 ? "󰝟" : OsdSource.value < 0.4 ? "󰕿" : OsdSource.value < 0.75 ? "󰖀" : "󰕾")
        : "󰃠"

    anchors.fill: parent

    BarPill {
        id: pill
        // Grows from a small drop (the bar's edge) to the full pill and back.
        readonly property real grow: root.on ? 1 : 0
        property real g: grow
        Behavior on g { NumberAnimation { duration: root.on ? 380 : 220; easing.type: root.on ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.6 } }
        width: 30 + 148 * g
        height: 46 * Math.max(0, g)
        x: Math.round(root.centreX - width / 2)
        y: root.barH + 4
        cornerRadius: Math.min(height, width) / 2.2
        visible: g > 0.02
        strong: true
        shadow: true

        // The bar is the middle; the icon and the number sit at its ends (so that it is in the middle of the drop).
        Item {
            id: content
            anchors.centerIn: parent
            width: 96 + 2 * (28 + 8)
            height: 30
            opacity: Math.max(0, (pill.g - 0.55) / 0.45)

            CenteredText {
                id: iconText
                anchors.right: barTrack.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: root.icon
                color: Theme.text
                font.pixelSize: 19
                // A little pop whenever the value changes.
                scale: 1
                SequentialAnimation {
                    id: pop
                    NumberAnimation { target: iconText; property: "scale"; to: 1.25; duration: 70 }
                    NumberAnimation { target: iconText; property: "scale"; to: 1; duration: 160; easing.type: Easing.OutBack }
                }
                Connections {
                    target: OsdSource
                    function onValueChanged() { pop.restart() }
                }
            }

            Rectangle {
                id: barTrack
                anchors.centerIn: parent
                width: 96
                height: 10
                radius: 5
                color: Qt.alpha(Theme.text, 0.14)

                Rectangle {
                    width: root.shown <= 0 ? 0 : height + root.shown * (parent.width - height)   // (the tip's middle is at the value)
                    height: parent.height
                    radius: 5
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Qt.alpha(Theme.accent, 0.55) }
                        GradientStop { position: 1; color: Theme.accent }
                    }
                    Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    // The bright tip.
                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 10
                        height: 10
                        radius: 5
                        color: Theme.text
                    }
                }
            }

            CenteredText {
                anchors.left: barTrack.right
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(root.shown * 100)
                color: Theme.text
                font.pixelSize: 15
                font.bold: true
            }
        }
    }
}
