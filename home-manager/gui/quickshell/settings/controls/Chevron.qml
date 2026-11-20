import QtQuick
import qs.shared

// The triangle of something that opens: ▸ closed, ▾ open.
Text {
    property bool open: false

    width: 16
    horizontalAlignment: Text.AlignHCenter
    text: open ? "▾" : "▸"
    color: Theme.textSecondary
    font.pixelSize: Theme.textMedium
}
