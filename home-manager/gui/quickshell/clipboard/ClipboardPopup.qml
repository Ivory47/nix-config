import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.shared

PanelWindow {
    id: root
    WlrLayershell.namespace: "clipboard"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    visible: false
    focusable: true

    color: "transparent"

    // When true, Ctrl+V is also sent to the window you were in after picking an entry (needs wtype).
    // Off by default because terminals use Ctrl+Shift+V.
    property bool autoPaste: false

    // Index to select after the list changes (used to stay in place after deleting).
    property int keepIndex: -1

    function open() {
        searchField.text = ""
        clipboardModel.refresh()
        root.visible = true
        searchField.forceActiveFocus()
    }

    function close() {
        root.visible = false
    }

    function toggle() {
        if (root.visible)
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

    RectangularShadow {
        anchors.fill: panel

        radius: panel.radius

        blur: 14
        spread: 2

        color: Theme.shadowColor

        offset.x: 0
        offset.y: 4
    }

    Rectangle {
        id: panel

        anchors.centerIn: parent

        width: 480
        height: Math.min(560, root.height - 80)

        radius: Theme.radiusLarge
        color: Theme.background

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
                    color: Theme.surface
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
                    required property var modelData
                    required property int index

                    entry: modelData
                    selected: index === list.currentIndex

                    width: list.width

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
