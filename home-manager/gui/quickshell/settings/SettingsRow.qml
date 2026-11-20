import QtQuick
import qs.shared

// One setting: label (and an optional note) on the left, the control in the column on the right, then a reset
// button that shows when the value was changed in the settings app. `below` is for what opens
// under the row (the colour picker). Nothing here is translucent: the popup is over live glass.
Item {
    id: root

    required property var spec
    default property alias control: controls.data
    property alias below: belowSlot.data
    property real belowHeight: 0

    readonly property bool overridden: !!spec.key && ThemeStore.isSet(spec.key)
    // A value of a widget's own look that it does not set: it follows the default look (dimmed).
    readonly property bool inherited: !!spec.inherits && !overridden
    // The small grey text under the label (a row may show something live instead of the schema's).
    property string note: spec.note || ""

    // Outlines the row for a moment, so that it can be found (after "show in page", an undo).
    function flash() {
        frame.flash()
    }
    FlashFrame { id: frame }

    width: parent ? parent.width : 0
    height: mainHeight + belowHeight

    // The controls take a column of the same width in every row (sliders and choices fill it, the
    // others sit at its right), so that they line up from row to row.
    readonly property real controlColumn: Math.min(340, width * 0.55)
    // The row without what opens under it: 44, or more when the note wraps.
    readonly property real mainHeight: Math.max(44, label.height + 14)

    // Never under the controls: the note wraps (up to three lines), the label is cut off.
    SettingsLabel {
        id: label
        wrap: true
        y: (root.mainHeight - height) / 2
        label: root.spec.label
        labelColor: root.inherited ? Theme.textSecondary : Theme.text
        note: root.note
        width: Math.max(0, controlSlot.x - Theme.spacingLarge)
    }

    Item {
        id: controlSlot
        anchors.right: resetButton.left
        anchors.rightMargin: Theme.spacingSmall
        y: (root.mainHeight - 44) / 2
        height: 44
        width: Math.max(root.controlColumn, controls.width)

        Item {
            id: controls
            anchors.right: parent.right
            height: 44
            width: childrenRect.width
        }
    }

    ResetButton {
        id: resetButton
        y: (root.mainHeight - 44) / 2 + 11
        active: root.overridden
        onClicked: ThemeStore.reset(root.spec.key)
    }

    Item {
        id: belowSlot
        anchors.left: parent.left
        anchors.right: parent.right
        y: root.mainHeight
        height: root.belowHeight
    }
}
