import QtQuick
import QtQuick.Controls
import qs.shared

// A popup with a search field above a list, on the glass: what the app launcher and the clipboard
// history have in common. Give it `model`, a `delegate` (a GlassListRow), the panel's size and the
// `ipcTarget`; the rest is built in:
//  - the panel, its glass and the highlights, the search field, the list, an "empty" text;
//  - keys in the field: Esc closes, Up / Down move, Enter emits `accepted(index)`; every other key is
//    offered to `keyPressed(event)` (set `event.accepted` there);
//  - a fresh start on closing (search text cleared, first row selected, list at the top);
//  - everything of GlassPopup (one widget at a time, click outside, workspace change, IPC).
// What a popup adds: the model, the delegate, what Enter does, extra keys, and its own items.
GlassPopup {
    id: root

    property string placeholder: "Search..."
    property var model: null
    property Component delegate: null
    property string emptyText: "Nothing here"
    // Shown instead of `emptyText` while a search is going on.
    property string noMatchText: "No matches"
    property real panelWidth: 480
    property real panelHeight: 400

    readonly property alias searchField: searchField
    readonly property alias list: list
    property alias searchText: searchField.text

    // Enter on the current row.
    signal accepted(int index)
    // A key the field did not use (Tab, Ctrl+C, ...): set event.accepted to stop it.
    signal keyPressed(var event)

    focusItem: searchField
    panelItem: panel

    onPopupClosed: {
        searchField.text = ""
        list.currentIndex = list.count > 0 ? 0 : -1
        list.positionViewAtBeginning()
    }

    GlassListPanel {
        // Placed in the surface's coordinates (whole pixels, as the glass needs).
        x: Math.round(panel.x)
        y: Math.round(panel.y)
        width: panel.width
        height: panel.height

        popup: root
        shadow: true
        panelOpacity: Theme.popupOpacity
        field: searchField
        listView: list
    }

    Rectangle {
        id: panel

        anchors.centerIn: parent
        width: root.panelWidth
        height: root.panelHeight
        radius: Theme.radiusLarge
        color: "transparent"
        border.width: 1
        border.color: Theme.surfaceAlt

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingLarge
            spacing: Theme.spacingMedium

            TextField {
                id: searchField

                width: parent.width
                height: 50
                leftPadding: Theme.spacingMedium
                rightPadding: Theme.spacingMedium

                placeholderText: root.placeholder
                font.pixelSize: Theme.textMedium
                color: Theme.text
                placeholderTextColor: Theme.textMuted

                background: Rectangle {
                    radius: Theme.radiusMedium
                    color: "transparent" // drawn by the glass (hlRect0)
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        root.closePopup()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Down) {
                        if (list.count > 0)
                            list.currentIndex = Math.min(list.currentIndex + 1, list.count - 1)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Up) {
                        if (list.count > 0)
                            list.currentIndex = Math.max(list.currentIndex - 1, 0)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (list.currentIndex >= 0 && list.currentIndex < list.count)
                            root.accepted(list.currentIndex)
                        event.accepted = true
                    } else {
                        event.accepted = false
                        root.keyPressed(event)
                    }
                }
            }

            ListView {
                id: list

                // The rows (GlassListRow) report the hovered row to this window.
                property var popupWindow: root

                width: parent.width
                height: parent.height - searchField.height - Theme.spacingMedium
                spacing: Theme.spacingSmall
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                // Touchpad scrolling keeps its momentum.
                KineticScroll {
                    target: list
                }

                model: root.model
                delegate: root.delegate
                currentIndex: count > 0 ? 0 : -1

                onCurrentIndexChanged: {
                    if (currentIndex >= 0)
                        positionViewAtIndex(currentIndex, ListView.Contain)
                }

                Text {
                    anchors.centerIn: parent
                    visible: list.count === 0
                    text: searchField.text === "" ? root.emptyText : root.noMatchText
                    color: Theme.textMuted
                    font.pixelSize: Theme.textMedium
                }
            }
        }
    }
}
