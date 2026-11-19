import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.shared
import qs.shared.glass

// The clipboard history: the model, the rows, picking and deleting. The panel, search, keys, glass and
// opening and closing are GlassSearchPopup's (and GlassPopup's); see there.
GlassSearchPopup {
    id: root
    WlrLayershell.namespace: "clipboard"
    // Own tag colour (bar 30, launcher 34 by default), see GlassBackdrop.tagRed.
    tagRed: 38

    ipcTarget: "clipboard"
    // Ignores "one widget at a time" (shared/Widgets.qml): other widgets neither close it nor does it close them.
    exclusive: false

    placeholder: "Search clipboard history..."
    emptyText: "Clipboard history is empty"
    panelWidth: 480
    panelHeight: Math.min(560, root.height - 80)

    model: clipboardModel.filteredEntries

    delegate: ClipboardItem {
        required property var modelData
        required property int index

        entry: modelData
        width: ListView.view.width
        onActivated: root.pick(index)
    }

    // When true, Ctrl+V is also sent to the window you were in after picking an entry (needs wtype).
    // Off by default because terminals use Ctrl+Shift+V.
    property bool autoPaste: false

    // Index to select after the list changes (used to stay in place after deleting).
    property int keepIndex: -1

    // A fresh list every time it opens.
    onAboutToOpen: {
        searchText = ""
        clipboardModel.refresh()
    }

    onAccepted: index => pick(index)

    // Shift+Delete removes the selected entry from history.
    onKeyPressed: event => {
        if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) {
            removeAt(list.currentIndex)
            event.accepted = true
        }
    }

    function pick(index) {
        const entry = clipboardModel.filteredEntries[index]

        if (!entry)
            return

        clipboardModel.copy(entry)
        closePopup()
    }

    function removeAt(index) {
        const entry = clipboardModel.filteredEntries[index]

        if (!entry)
            return

        keepIndex = index
        clipboardModel.remove(entry)
    }

    ClipboardWatcher {}

    ClipboardModel {
        id: clipboardModel

        searchText: root.searchText

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
