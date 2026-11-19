import QtQuick
import qs.shared

// One segment of the overlay's dark plates (the list filter at the top, the existing tags offered while a
// tag is typed): a Chip with the unthemed on-image palette (OnImage). It fills the height it is given, no
// outline, solid in the accent colour when `selected`, lighter while the mouse is over it.
Chip {
    id: root

    pill: true
    outlined: false
    horizontalPadding: 32
    rowSpacing: 7
    fontSize: Theme.textMedium
    countFontSize: Theme.textSmall
    boldWhenSelected: true

    hoverFill: OnImage.inkA(0.14)
    textColor: OnImage.ink
    countColor: OnImage.inkA(0.55)
    selectedCountColor: OnImage.shadeA(0.55)
}
