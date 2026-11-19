import QtQuick

// Which wallpapers are listed: the bar at the top of the screen (Tab). A segmented control on a dark
// plate (so that it reads over whatever is on the desktop): the chips fill the plate's height, the
// chosen one is solid, the others have no outline.
Rectangle {
    id: filterPlate

    required property var overlay

    readonly property int pad: 4
    opacity: overlay.shown && !overlay.filterPending ? 1 : 0
    anchors.horizontalCenter: parent.horizontalCenter
    y: Math.max(24, Math.round(overlay.height / 4 - 74))
    width: filterBar.width + 2 * pad
    height: 40
    radius: height / 2
    color: overlay.plateColor
    border.width: 1
    border.color: OnImage.inkA(0.14)
    Behavior on opacity {
        NumberAnimation { duration: 180 }
    }

    ListView {
        id: filterBar
        anchors.centerIn: parent
        width: Math.min(overlay.width * 0.8, contentWidth)
        height: filterPlate.height - 2 * filterPlate.pad - 2
        orientation: ListView.Horizontal
        spacing: 2
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: overlay.filterChips

        // Keep the chosen chip in view.
        property int chosenIndex: Math.max(0, overlay.filterChips.findIndex(c => c.tag === overlay.filterTag))
        onChosenIndexChanged: positionViewAtIndex(chosenIndex, ListView.Contain)

        delegate: SegmentChip {
            required property var modelData
            text: modelData.label
            count: modelData.count
            selected: modelData.tag === overlay.filterTag
            height: filterBar.height
            onClicked: overlay.setFilter(modelData.tag)
        }
    }
}
