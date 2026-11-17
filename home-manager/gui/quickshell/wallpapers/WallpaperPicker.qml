import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.shared
import qs.shared.glass

// The wallpaper picker: browse ~/Pictures/Wallpapers, pick one of the colours matugen finds in a
// wallpaper (and a scheme type, light or dark), tag wallpapers and search by name or tag, then
// apply it (awww for the picture, matugen for the colours). The window, the glass and the opening
// and closing are GlassPopup's (see there), the panel is the launcher's.
//
// Keys (typed in the search field, which has the keyboard): arrows move in the grid, Enter applies
// and closes, Alt+1..5 picks a colour, Alt+Left/Right the scheme type, Alt+M light/dark, Ctrl+T goes to the tag field (Esc comes back), Esc clears the
// search and the tag filters and then closes, Ctrl+C closes.
GlassPopup {
    id: root
    WlrLayershell.namespace: "wallpapers"
    tagRed: 42    // bar 30, launcher and settings 34, clipboard 38

    focusItem: searchField

    // ---- what is selected -----------------------------------------------------------------------

    // Kept by name: the list is rebuilt when a tag is added or the search changes.
    property string selectedName: ""
    readonly property var currentEntry:
        (grid.currentIndex >= 0 && grid.currentIndex < wpModel.filtered.length) ? wpModel.filtered[grid.currentIndex] : null
    readonly property var sourceColors: ColorCache.colorsOf(currentEntry)

    // The colour, scheme type and mode picked for the selected wallpaper (saved per wallpaper).
    property int selIndex: 0
    property string selType: WallpaperStore.defaultType
    property string selMode: WallpaperStore.defaultMode

    readonly property string selColor:
        (sourceColors && sourceColors.length > 0) ? sourceColors[Math.min(selIndex, sourceColors.length - 1)] : ""
    readonly property var schemeRoles: selColor !== "" ? ColorCache.paletteOf(selColor, selType, selMode) : undefined
    readonly property string paletteKey: selColor !== "" ? ColorCache.paletteKey(selColor, selType, selMode) : ""
    onPaletteKeyChanged: if (selColor !== "") ColorCache.requestPalette(selColor, selType, selMode)

    readonly property var schemeTypes: [
        "scheme-tonal-spot", "scheme-vibrant", "scheme-expressive", "scheme-content", "scheme-fidelity",
        "scheme-fruit-salad", "scheme-rainbow", "scheme-neutral", "scheme-monochrome", "scheme-smart"
    ]

    onCurrentEntryChanged: {
        if (!currentEntry)
            return
        const c = WallpaperStore.choiceOf(currentEntry.name)
        selIndex = c.index
        selType = c.type
        selMode = c.mode
        ColorCache.prioritize(currentEntry)
        if (applier.state !== "running")
            applier.state = "idle"
    }

    function pickColor(i) {
        if (!currentEntry || !sourceColors || i < 0 || i >= sourceColors.length)
            return
        selIndex = i
        saveChoice()
    }
    function stepScheme(delta) {
        const n = schemeTypes.length
        const at = Math.max(0, schemeTypes.indexOf(selType))
        selType = schemeTypes[(at + delta + n) % n]
        saveChoice()
    }
    function setMode(m) {
        selMode = m
        saveChoice()
    }
    function saveChoice() {
        if (currentEntry)
            WallpaperStore.setChoice(currentEntry.name, selIndex, selType, selMode)
    }

    // The user chose (click, keys): stop following the wallpaper that is on the screen.
    property bool followCurrent: false
    function select(i) {
        grid.currentIndex = i
        userMoved()
    }
    function userMoved() {
        followCurrent = false
        syncSelected()
    }
    function syncSelected() {
        if (currentEntry)
            selectedName = currentEntry.name
    }
    // The list changed (search, tags, files): keep the same wallpaper selected if it is still there.
    function restoreSelection() {
        const n = wpModel.filtered.length
        const i = wpModel.indexOfName(selectedName)
        grid.currentIndex = i >= 0 ? i : (n > 0 ? 0 : -1)
        syncSelected()
    }
    function showSelected() {
        if (grid.currentIndex >= 0)
            grid.positionViewAtIndex(grid.currentIndex, GridView.Contain)
    }

    // ---- applying -------------------------------------------------------------------------------

    function apply(thenClose) {
        const e = currentEntry
        if (!e || applier.running)
            return
        applier.closeAfter = thenClose
        applier.state = "running"
        applier.message = ""
        applier.command = [
            "sh", "-c",
            'awww img -a "$1" && matugen image "$1" --source-color-index "$2" -t "$3" -m "$4" >/dev/null',
            "sh", e.path, String(selIndex), selType, selMode
        ]
        applier.running = true
    }

    Process {
        id: applier
        property string state: "idle"
        property string message: ""
        property bool closeAfter: false
        stderr: StdioCollector {
            id: applyErr
        }
        onExited: (code, status) => {
            if (code === 0) {
                state = "ok"
                wpModel.refreshCurrent()
                if (closeAfter)
                    root.shown = false
            } else {
                state = "error"
                message = applyErr.text.trim() || ("Failed (exit code " + code + ")")
            }
        }
    }

    // ---- window ---------------------------------------------------------------------------------

    onPopupOpened: {
        followCurrent = true
        wpModel.refreshCurrent()
        ColorCache.enqueue(wpModel.entries)
        if (wpModel.current !== "" && wpModel.indexOfName(wpModel.current) >= 0)
            selectedName = wpModel.current
        Qt.callLater(() => { root.restoreSelection(); root.showSelected() })
    }

    onPopupClosed: {
        // A fresh start the next time: no search, no tag filters.
        searchField.text = ""
        detail.tagField.text = ""
        wpModel.activeTags = []
    }

    function closePicker() {
        root.shown = false
    }

    Connections {
        target: Hyprland

        function onFocusedWorkspaceChanged() {
            root.shown = false
        }
    }

    IpcHandler {
        target: "wallpapers"

        function isOpen(): bool {
            return root.shown
        }

        function toggle() {
            root.shown = !root.shown
        }

        function show() {
            root.shown = true
        }

        function hide() {
            root.shown = false
        }
    }

    WallpaperModel {
        id: wpModel
        store: WallpaperStore
        query: searchField.text

        onFilteredChanged: Qt.callLater(root.restoreSelection)
        onCurrentChanged: {
            // The wallpaper on the screen was found after the popup opened.
            if (root.shown && root.followCurrent && indexOfName(current) >= 0)
                Qt.callLater(() => { root.selectedName = wpModel.current; root.restoreSelection(); root.showSelected() })
        }
        onEntriesChanged: if (root.shown) ColorCache.enqueue(entries)
    }

    // ---- the panel ------------------------------------------------------------------------------

    readonly property int margin: Theme.spacingLarge
    readonly property int detailWidth: 340

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
        listView: grid
    }

    Rectangle {
        id: panel

        anchors.centerIn: parent
        width: Math.round(Math.min(1120, root.width * 0.86))
        height: Math.round(Math.min(700, root.height * 0.86))

        radius: Theme.radiusLarge
        color: "transparent"

        border.width: 1
        border.color: Theme.surfaceAlt

        // ---- left: search, tag filters, grid ----
        Item {
            id: left
            x: root.margin
            y: root.margin
            width: panel.width - root.detailWidth - 3 * root.margin
            height: panel.height - 2 * root.margin

            TextField {
                id: searchField

                width: parent.width
                height: 46
                leftPadding: Theme.spacingMedium
                rightPadding: Theme.spacingMedium

                placeholderText: "Search wallpapers or #tags..."
                font.pixelSize: Theme.textMedium
                color: Theme.text
                placeholderTextColor: Theme.textMuted

                background: Rectangle {
                    radius: Theme.radiusMedium
                    color: "transparent" // drawn by the glass (hlRect0)
                }

                Component.onCompleted: forceActiveFocus()

                Keys.onPressed: event => {
                    const ctrl = event.modifiers & Qt.ControlModifier
                    const alt = event.modifiers & Qt.AltModifier
                    if (event.key === Qt.Key_Escape) {
                        if (text !== "" || wpModel.activeTags.length > 0) {
                            text = ""
                            wpModel.activeTags = []
                        } else {
                            root.closePicker()
                        }
                        event.accepted = true
                    } else if (event.key === Qt.Key_C && ctrl) {
                        root.closePicker()
                        event.accepted = true
                    } else if (event.key === Qt.Key_T && ctrl) {
                        detail.tagField.forceActiveFocus()
                        event.accepted = true
                    } else if (alt && event.key >= Qt.Key_1 && event.key <= Qt.Key_5) {
                        root.pickColor(event.key - Qt.Key_1)
                        event.accepted = true
                    } else if (alt && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
                        root.stepScheme(event.key === Qt.Key_Left ? -1 : 1)
                        event.accepted = true
                    } else if (alt && event.key === Qt.Key_M) {
                        root.setMode(root.selMode === "dark" ? "light" : "dark")
                        event.accepted = true
                    } else if (event.key === Qt.Key_Left) {
                        grid.moveCurrentIndexLeft(); root.userMoved(); event.accepted = true
                    } else if (event.key === Qt.Key_Right) {
                        grid.moveCurrentIndexRight(); root.userMoved(); event.accepted = true
                    } else if (event.key === Qt.Key_Up) {
                        grid.moveCurrentIndexUp(); root.userMoved(); event.accepted = true
                    } else if (event.key === Qt.Key_Down) {
                        grid.moveCurrentIndexDown(); root.userMoved(); event.accepted = true
                    } else if (event.key === Qt.Key_PageDown) {
                        select(Math.min(grid.currentIndex + grid.columns * 2, grid.count - 1)); event.accepted = true
                    } else if (event.key === Qt.Key_PageUp) {
                        select(Math.max(grid.currentIndex - grid.columns * 2, 0)); event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.apply(true)
                        event.accepted = true
                    }
                }
            }

            // Tag filters: a row of chips (scrolls sideways), all must match.
            Item {
                id: tagBar
                y: searchField.height + Theme.spacingMedium
                width: parent.width
                height: 28

                Text {
                    visible: wpModel.tagList.length === 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: "No tags yet. Select a wallpaper and add some on the right."
                    font.pixelSize: Theme.textSmall
                    color: Theme.textMuted
                }

                ListView {
                    anchors.fill: parent
                    orientation: ListView.Horizontal
                    spacing: 6
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: wpModel.tagList

                    delegate: TagChip {
                        required property var modelData
                        y: 1
                        text: modelData.tag
                        count: modelData.count
                        selected: wpModel.activeTags.indexOf(modelData.tag) >= 0
                        onClicked: {
                            const on = wpModel.activeTags
                            wpModel.activeTags = selected ? on.filter(t => t !== modelData.tag) : on.concat([modelData.tag])
                        }
                    }
                }
            }

            GridView {
                id: grid

                y: tagBar.y + tagBar.height + Theme.spacingMedium
                width: parent.width
                height: parent.height - y

                readonly property int columns: Math.max(2, Math.floor(width / 230))
                cellWidth: Math.floor(width / columns)
                cellHeight: Math.round((cellWidth - 16) * 0.56) + 8 + 8 + 6 + 20

                clip: true
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: -1
                model: wpModel.filtered
                cacheBuffer: cellHeight * 2

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 4
                        radius: 2
                        color: Theme.surfaceAlt
                    }
                    background: Item {}
                }

                delegate: WallpaperCard {
                    id: card

                    width: grid.cellWidth
                    height: grid.cellHeight
                    decodeWidth: (grid.cellWidth - 16) * root.devicePixelRatio
                    isCurrent: modelData.name === wpModel.current
                    colors: ColorCache.colorsOf(modelData)

                    // The glass highlights the hovered card (hlRect2) and the selected one (hlRect1).
                    onHoveredChanged: {
                        if (hovered)
                            root.hoveredItem = card
                        else if (root.hoveredItem === card)
                            root.hoveredItem = null
                    }

                    onActivated: {
                        root.select(index)
                        searchField.forceActiveFocus()
                    }
                    onApplied: {
                        root.select(index)
                        root.apply(true)
                    }
                }

                Text {
                    visible: grid.count === 0
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: wpModel.entries.length === 0
                        ? "No images in ~/Pictures/Wallpapers"
                        : "No wallpapers match"
                    font.pixelSize: Theme.textMedium
                    color: Theme.textMuted
                }
            }
        }

        Rectangle {
            x: left.x + left.width + root.margin / 2
            y: root.margin
            width: 1
            height: panel.height - 2 * root.margin
            color: Theme.surfaceAlt
        }

        // ---- right: the selected wallpaper ----
        DetailPane {
            id: detail

            x: panel.width - root.margin - root.detailWidth
            y: root.margin
            width: root.detailWidth
            height: panel.height - 2 * root.margin

            entry: root.currentEntry
            colors: root.sourceColors
            colorIndex: root.selIndex
            schemeType: root.selType
            mode: root.selMode
            roles: root.schemeRoles
            tags: root.currentEntry ? WallpaperStore.tagsOf(root.currentEntry.name) : []
            knownTags: wpModel.tagList
            isCurrent: !!root.currentEntry && root.currentEntry.name === wpModel.current
            applyState: applier.state
            applyMessage: applier.message

            onColorPicked: index => root.pickColor(index)
            onSchemeStepped: delta => root.stepScheme(delta)
            onModeSet: m => root.setMode(m)
            onTagAdded: text => { if (root.currentEntry) WallpaperStore.addTags(root.currentEntry.name, text) }
            onTagRemoved: tag => { if (root.currentEntry) WallpaperStore.removeTag(root.currentEntry.name, tag) }
            onApplyRequested: root.apply(false)
            onLeaveToSearch: searchField.forceActiveFocus()
        }
    }
}
