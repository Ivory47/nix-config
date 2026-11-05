import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.shared
import qs.shared.glass

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

    // The window stays mapped: Quickshell destroys and re-creates the Qt window when `visible`
    // goes false and true again, and the glass items crash that re-creation (segfault in
    // QQuickWindow::maybeUpdate). So only `shown` changes: no input, no focus and no content
    // while hidden, and the glass capture is off. (Same as the app launcher.)
    property bool shown: false
    // The list row under the mouse, if any (highlighted by the glass).
    property Item hoveredItem: null

    // Take the keyboard exclusively while shown ("focusable" only asks for it on demand, which
    // the compositor does not always grant to a window that was already mapped).
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: shown ? null : emptyMask

    Region {
        id: emptyMask
    }

    color: "transparent"

    // The glass is drawn from the background it saved the last time the popup was open, and it
    // subtracts that old picture of what leaks through it: when the screen behind has changed,
    // the old content shows up inverted until the first new capture. So until the pipeline has
    // taken fresh captures (a few frames) the glass does not subtract anything (cancelLeak), and
    // then it is ramped in. See app-launcher/Launcher.qml, which does the same.
    property bool revealed: false
    property int flipsAtOpen: 0
    property real cancelAmount: 0

    NumberAnimation {
        id: cancelRamp
        target: root
        property: "cancelAmount"
        from: 0
        to: 1
        duration: 150
    }

    function reveal() {
        revealTimer.stop()
        revealed = true
        cancelRamp.restart()
    }

    Timer {
        // In case no capture comes (nothing changed behind, so the old picture is right).
        id: revealTimer
        interval: 400
        onTriggered: root.reveal()
    }

    Connections {
        target: glassBackdrop

        function onFlipsChanged() {
            // Two updates: the first capture may predate the surface and be refused.
            if (root.shown && !root.revealed && glassBackdrop.flips >= root.flipsAtOpen + 2)
                root.reveal()
        }
    }

    onShownChanged: {
        revealTimer.stop()
        cancelRamp.stop()
        cancelAmount = 0
        revealed = false

        if (shown) {
            flipsAtOpen = glassBackdrop.flips
            revealTimer.start()
            searchField.forceActiveFocus()
            // Again once the compositor has handed over the keyboard.
            focusTimer.restart()
        }
    }

    Timer {
        id: focusTimer
        interval: 60
        onTriggered: if (root.shown) searchField.forceActiveFocus()
    }

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
        // A fresh start the next time.
        searchField.text = ""
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

    Item {
        id: content
        anchors.fill: parent
        visible: root.shown

        // Click outside the panel to close.
        MouseArea {
            anchors.fill: parent

            onClicked: root.close()
        }

        // No drop shadow behind the panel: a shadow under the glass lowers how much of the
        // background shows through it (the shader cancels exactly that part), and the sharp
        // background then shows faintly through the glass.

        GlassPanel {
            id: glass

            // Placed in the backdrop's coordinates (whole pixels, as the glass needs).
            x: Math.round(panel.x)
            y: Math.round(panel.y)
            width: panel.width
            height: panel.height

            backdrop: glassBackdrop

            // Highlights are part of the glass (see GlassPanel.hlRect0): the search field, the
            // selected row and the hovered row. Rows are clipped to the visible list.
            hlRadius: Theme.radiusMedium
            cancelLeak: root.cancelAmount
            hlRect0: {
                panel.x; panel.y; glass.x; glass.y
                return glass.rectOf(searchField, false)
            }
            hlColor0: Qt.vector4d(Theme.surfaceAlt.r, Theme.surfaceAlt.g, Theme.surfaceAlt.b, 0.55)
            hlRect1: {
                list.contentY; list.currentIndex; panel.x; panel.y; glass.x; glass.y
                return glass.rectOf(list.currentItem, true)
            }
            hlColor1: Qt.vector4d(Theme.surfaceAlt.r, Theme.surfaceAlt.g, Theme.surfaceAlt.b, 0.7)
            hlRect2: {
                list.contentY; panel.x; panel.y; glass.x; glass.y
                return glass.rectOf(root.hoveredItem, true)
            }
            hlColor2: Qt.vector4d(Theme.surfaceAlt.r, Theme.surfaceAlt.g, Theme.surfaceAlt.b, 0.5)

            // `item` in this panel's coordinates; the list's rows are cut at the list's edges.
            function rectOf(item, inList) {
                if (!item) return Qt.vector4d(0, 0, 0, 0)
                const p = item.mapToItem(glass, 0, 0)
                let top = p.y
                let bottom = p.y + item.height
                if (inList) {
                    const l = list.mapToItem(glass, 0, 0)
                    top = Math.max(top, l.y)
                    bottom = Math.min(bottom, l.y + list.height)
                    if (bottom <= top) return Qt.vector4d(0, 0, 0, 0)
                }
                return Qt.vector4d(p.x, top, item.width, bottom - top)
            }

            style: GlassStyle {
                cornerRadius: Theme.radiusLarge
                edges: Qt.vector4d(1, 1, 1, 1)

                // The old panel colour over the blur, translucent.
                tint: Theme.background
                tintStrength: 0.65
                // Fully frosted: any sharp background mixed into the glass shows as faint text.
                frost: 1.0
            }
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

        // One opaque pixel at the top left: says which version of the surface a capture holds.
        GlassTag {
            backdrop: glassBackdrop
        }
    }

    // Live glass (shared/glass): captures and unmixes what is behind this surface. Only while shown.
    GlassBackdrop {
        id: glassBackdrop
        composite: content
        blurRadius: 14
        ipcTarget: "glass"
        active: root.shown
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
