import QtQuick
import qs.shared

// The small title of a block inside a settings section (ThemeSchema `blocks`: "Tone", "Rim", "Base", ...).
Text {
    topPadding: Theme.spacingMedium
    bottomPadding: 2
    leftPadding: 0
    color: Theme.textSecondary
    font.pixelSize: Theme.textSmall - 1
    font.bold: true
    font.capitalization: Font.AllUppercase
    font.letterSpacing: 0.6
}
