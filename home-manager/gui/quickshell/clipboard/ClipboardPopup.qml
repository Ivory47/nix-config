import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.shared
import qs.shared.glass

// The window, the glass and the opening and closing are GlassPopup's; see there.
GlassPopup {
    id: root
    WlrLayershell.namespace: "clipboard"

    focusItem: searchField

    // A fresh start the next time.
    onPopupClosed: searchField.text = ""

    // When true, Ctrl+V is also sent to the window you were in after picking an entry (needs wtype).
    // Off by default because terminals use Ctrl+Shift+V.
    property bool autoPaste: false

    // Index to select after the list changes (used to stay in place after deleting).
    property int keepIndex: -1

    function open() {
        searchField.text = ""
        clipboardModel.refresh()
        root.shown = true
    }

    function close() {
        root.shown = false
    }

    function toggle() {
        if (root.shown)
            close()
        else
            open()
    }

    function pick(index) {
        const entry = clipboardModel.filteredEntries[index]

        if (!entry)
            return

        clipboardModel.copy(entry)
        close()
    }

    function removeAt(index) {
        const entry = clipboardModel.filteredEntries[index]

        if (!entry)
            return

        keepIndex = index
        clipboardModel.remove(entry)
    }

    Connections {
        target: Hyprland

        function onFocusedWorkspaceChanged() {
            root.close()
        }
    }

    IpcHandler {
        target: "clipboard"

        function toggle(): void {
            root.toggle()
        }

        function show(): void {
            root.open()
        }

        function hide(): void {
            root.close()
        }
    }

    ClipboardWatcher {}

    ClipboardModel {
        id: clipboardModel

        searchText: searchField.text

        onCopied: {
            if (root.autoPaste)
                pasteTimer.start()
        }
    }

    Timer {
        id: pasteTimer

        interval: 150

        onTriggered: pasteProcess.running = true
    }

    Process {
        id: pasteProcess

        command: ["wtype", "-M", "ctrl", "-k", "v", "-m", "ctrl"]
    }

    // Click outside the panel to close.
    MouseArea {
        anchors.fill: parent

        onClicked: root.close()
    }

    GlassListPanel {
        // Placed in the surface's coordinates (whole pixels, as the glass needs).
        x: Math.round(panel.x)
        y: Math.round(panel.y)
        width: panel.width
        height: panel.height

        popup: root
        field: searchField
        listView: list
    }

    Rectangle {
        id: panel

        anchors.centerIn: parent

        width: 480
        height: Math.min(560, root.height - 80)

        radius: Theme.radiusLarge
        color: "transparent"

        border.width: 1
        border.color: Theme.surfaceAlt

        // Keeps clicks inside the panel from closing it.
        MouseArea {
            anchors.fill: parent
        }

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

                placeholderText: "Search clipboard history..."
                font.pixelSize: Theme.textMedium

                color: Theme.text
                placeholderTextColor: Theme.textMuted

                background: Rectangle {
                    radius: Theme.radiusMedium
                    color: "transparent" // drawn by the glass (hlRect0)
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        root.close()
                        event.accepted = true
                    }

                    else if (event.key === Qt.Key_Down) {
                        if (list.count > 0)
                            list.currentIndex = Math.min(list.currentIndex + 1, list.count - 1)

                        event.accepted = true
                    }

                    else if (event.key === Qt.Key_Up) {
                        if (list.count > 0)
                            list.currentIndex = Math.max(list.currentIndex - 1, 0)

                        event.accepted = true
                    }

                    else if (event.key === Qt.Key_Return ||
                    event.key === Qt.Key_Enter) {
                        root.pick(list.currentIndex)
                        event.accepted = true
                    }

                    // Shift+Delete removes the selected entry from history.
                    else if (event.key === Qt.Key_Delete &&
                    (event.modifiers & Qt.ShiftModifier)) {
                        root.removeAt(list.currentIndex)
                        event.accepted = true
                    }
                }
            }

            ListView {
                id: list

                width: parent.width
                height: parent.height
                    - searchField.height
                    - Theme.spacingMedium

                spacing: Theme.spacingSmall

                clip: true

                model: clipboardModel.filteredEntries

                currentIndex: count > 0 ? 0 : -1

                onCurrentIndexChanged: {
                    if (currentIndex >= 0)
                        positionViewAtIndex(currentIndex, ListView.Contain)
                }

                delegate: ClipboardItem {
                    id: row

                    required property var modelData
                    required property int index

                    entry: modelData
                    selected: index === list.currentIndex

                    width: list.width

                    // The glass highlights the row under the mouse (hlRect2).
                    onHoveredChanged: {
                        if (hovered)
                            root.hoveredItem = row
                        else if (root.hoveredItem === row)
                            root.hoveredItem = null
                    }

                    onPicked: root.pick(index)
                }

                Text {
                    anchors.centerIn: parent

                    visible: list.count === 0

                    text: searchField.text === ""
                        ? "Clipboard history is empty"
                        : "No matches"

                    color: Theme.textMuted
                    font.pixelSize: Theme.textMedium
                }
            }
        }
    }

    Connections {
        target: clipboardModel

        function onFilteredEntriesChanged() {
            const count = clipboardModel.filteredEntries.length
            const wanted = root.keepIndex >= 0 ? root.keepIndex : 0

            root.keepIndex = -1

            list.currentIndex = count > 0
                ? Math.min(wanted, count - 1)
                : -1
        }
    }
}
