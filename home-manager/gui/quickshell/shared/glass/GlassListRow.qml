import QtQuick
import qs.shared

// The base of a row in a GlassSearchPopup's list: the click area, `selected` (the current row) and
// `hovered`, and the plumbing that tells the popup which row is under the mouse (the glass draws the
// highlights, GlassListPanel). The row's background is always transparent: a translucent item over the
// glass would cost the blur under it. Put the row's content inside; emit nothing yourself:
// handle `activated()` (a click) in the delegate. Needs to be a delegate of a GlassSearchPopup's list.
Item {
    id: row

    signal activated()

    readonly property bool selected: ListView.isCurrentItem
    readonly property bool hovered: mouseArea.containsMouse

    // `hoveredItem` of the popup that owns the list (GlassSearchPopup sets `popupWindow` on its ListView).
    onHoveredChanged: {
        const popup = ListView.view?.popupWindow
        if (!popup)
            return
        if (hovered)
            popup.hoveredItem = row
        else if (popup.hoveredItem === row)
            popup.hoveredItem = null
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        z: 0
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.activated()
    }

    // Content declared inside the row goes above the click area.
    default property alias content: contentItem.data
    Item {
        id: contentItem
        anchors.fill: parent
        z: 1
    }
}
