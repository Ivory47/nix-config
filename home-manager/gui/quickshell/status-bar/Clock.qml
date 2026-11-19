import QtQuick
import qs.shared

// The time (or date), updated every second. Centred on its optical middle (CenteredText), so that it
// lines up with lines, badges and other text next to it.
CenteredText {
    id: root

    property string format: "HH:mm"
    property string now: Qt.formatDateTime(new Date(), format)

    text: now
    color: Theme.text
    font.pixelSize: 14

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = Qt.formatDateTime(new Date(), root.format)
    }
    onFormatChanged: now = Qt.formatDateTime(new Date(), format)
}
