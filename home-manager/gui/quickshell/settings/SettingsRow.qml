import QtQuick
import qs.shared

// One setting: label (and an optional note) on the left, the control on the right, then a reset
// button that shows when the value was changed in the settings app. `below` is for what opens
// under the row (the colour picker). Nothing here is translucent: the popup is over live glass.
Item {
    id: root

    required property var spec
    default property alias control: controlSlot.data
    property alias below: belowSlot.data
    property real belowHeight: 0

    readonly property bool overridden: ThemeStore.isSet(spec.key)

    // Outlines the row for a moment, so that it can be found (after "show in page"). An outline
    // that is on or off, not faded: nothing translucent over the glass.
    property bool flashing: false
    function flash() {
        flashing = true
        flashTimer.restart()
    }
    Timer {
        id: flashTimer
        interval: 1400
        onTriggered: root.flashing = false
    }
    Rectangle {
        visible: root.flashing
        x: -4
        y: 2
        width: root.width + 8
        height: root.height - 4
        radius: Theme.radiusMedium
        color: "transparent"
        border.width: 2
        border.color: Theme.accent
    }

    width: parent ? parent.width : 0
    height: 44 + belowHeight

    // Never under the control: the text is cut off with an ellipsis before it gets there.
    SettingsLabel {
        label: root.spec.label
        note: root.spec.note || ""
        width: Math.max(0, controlSlot.x - Theme.spacingMedium)
    }

    Item {
        id: controlSlot
        anchors.right: resetButton.left
        anchors.rightMargin: Theme.spacingSmall
        y: 0
        height: 44
        width: childrenRect.width
    }

    ResetButton {
        id: resetButton
        active: root.overridden
        onClicked: ThemeStore.reset(root.spec.key)
    }

    Item {
        id: belowSlot
        anchors.left: parent.left
        anchors.right: parent.right
        y: 44
        height: root.belowHeight
    }
}
