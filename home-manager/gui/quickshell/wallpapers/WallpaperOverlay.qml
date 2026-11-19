import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Glass.Native
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.shared

// The wallpaper picker as an OVERLAY: a full-screen layer-shell surface over the desktop (dimmed a
// little) with the selected wallpaper big in the middle, half the screen's width and height, and the
// neighbouring wallpapers peeking out on both sides. Scroll (wheel, touchpad) or press Left / Right to
// go through them; every wallpaper you stop on is applied to the desktop at once (awww, then matugen
// for the colours). The colours matugen finds in the selected wallpaper are on the image at the
// bottom: click one, or press Shift+Left / Shift+Right (or 1 to 5), to use it. The top of the
// picture has the wallpaper's tags and its star; the bar at the top of the screen picks which
// wallpapers are in the list: the favourites (the built-in tag, shown first when there are any), all of
// them, or one tag. (WallpaperPicker.qml is the same thing as a normal window, with more controls.)
//
// Keys: Left / Right (also H / L) wallpaper; Shift+Left / Shift+Right (Up / Down, 1 to 5) colour;
// Home / End first / last; Tab / Shift+Tab which wallpapers are listed; F favourite; T add a tag
// (existing tags are offered under it: click, or Down / Up + Enter, or Tab; Enter adds what is typed, Esc cancels); Space applies the one in the middle if it is not applied yet; Enter applies
// it and closes; Esc or Ctrl+C close. A click outside the pictures closes it.
//
// Nothing here uses the glass: the overlay is a picture over the desktop, so it is a plain window
// (no GlassPopup, no capture). Like the glass popups it never changes `visible`: the window stays
// mapped, `shown` only decides whether it takes input and shows anything.
PanelWindow {
    id: root

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "wallpapers-overlay"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // Open / closed (IPC in shell.qml).
    property bool shown: false
    mask: shown ? null : emptyMask

    Region {
        id: emptyMask
    }

    // ---- the wallpapers, the list and the selection -----------------------------------------------

    WallpaperModel {
        id: wpModel
        store: WallpaperStore
        // Which wallpapers are listed: all (""), or the ones with the tag.
        activeTags: root.filterTag === "" ? [] : [root.filterTag]

        // The wallpaper that is on the screen was found (or changed): the selection starts there.
        onCurrentChanged: {
            if (!applier.running && !root.pending && current !== "")
                root.appliedName = current
            root.followCurrentNow()
        }
        // `awww query` answered: now the opening list and selection can be chosen.
        onCurrentKnownChanged: root.chooseInitialFilter(false)
        onEntriesChanged: {
            root.chooseInitialFilter(false)
            root.followCurrentNow()
            if (root.shown)
                ColorCache.enqueue(entries)
        }
        // A tag was added or taken off, or the filter changed: the list is new.
        onFilteredChanged: root.restoreSelection()
    }

    // The tag that is listed ("" = all) and whether the opening choice still has to be made (the
    // files may be read after the window opens).
    property string filterTag: ""
    property bool filterPending: false

    // The listed wallpapers (the model's `filtered`).
    readonly property var entries: wpModel.filtered
    // The selection: index into `entries` (and its file name, to find it again when the list changes),
    // and the same as a number that glides (the carousel is drawn from it).
    property int selected: 0
    property string selectedName: ""
    property real pos: selected
    Behavior on pos {
        // No glide while the opening selection is still being chosen (the pictures are not shown yet).
        enabled: !root.filterPending
        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
    }

    readonly property var entry: (selected >= 0 && selected < entries.length) ? entries[selected] : null

    // Until the user has moved, the selection follows the wallpaper that is on the screen.
    property bool followCurrent: false

    function setSelected(i) {
        selected = i
        selectedName = (i >= 0 && i < entries.length) ? entries[i].name : ""
    }

    function followCurrentNow() {
        if (!followCurrent)
            return
        const i = wpModel.indexOfName(wpModel.current)
        if (i >= 0)
            setSelected(i)
    }

    // The list changed: stay on the same wallpaper if it is still there, else on the same place.
    function restoreSelection() {
        // (The model can say its list changed while it is still being set up, before `entries` is bound.)
        if (!entries)
            return
        const n = entries.length
        if (n === 0) {
            selected = 0
            selectedName = ""
            return
        }
        const i = wpModel.indexOfName(selectedName)
        setSelected(i >= 0 ? i : Math.min(selected, n - 1))
    }

    function select(i) {
        const n = entries.length
        if (n === 0)
            return
        i = Math.max(0, Math.min(n - 1, i))
        if (i === selected)
            return
        followCurrent = false
        setSelected(i)
        // The selection is applied when it has rested for a moment, not at every step of a fast scroll.
        wallpaperTimer.restart()
    }

    function step(d) {
        select(selected + d)
    }

    onEntryChanged: {
        if (entry) {
            ColorCache.prioritize(entry)
            for (const d of [-1, 1, -2, 2]) {
                const e = entries[selected + d]
                if (e)
                    ColorCache.prioritize(e)
            }
        }
    }

    // ---- which wallpapers are listed --------------------------------------------------------------

    // The chips of the bar at the top: favourites, all, and the other tags (with how many each has).
    readonly property var filterChips: {
        const names = wpModel.entries.map(e => e.name)
        const fav = WallpaperStore.favouriteTag
        const out = [
            { tag: fav, label: "★ Favourites", count: WallpaperStore.favouriteCount(names) },
            { tag: "", label: "All", count: names.length }
        ]
        for (const t of wpModel.tagList)
            if (t.tag !== fav)
                out.push({ tag: t.tag, label: t.tag, count: t.count })
        return out
    }

    // On opening: the selection starts on the wallpaper on the screen. It waits until
    // `awww query` has answered, so that the pictures are never shown on the wrong one first
    // (`force`: the fallback timer, when awww does not answer).
    function chooseInitialFilter(force) {
        if (!filterPending || wpModel.entries.length === 0)
            return
        if (!wpModel.currentKnown && !force)
            return
        const names = wpModel.entries.map(e => e.name)
        const cur = wpModel.current
        const known = cur !== "" && names.indexOf(cur) >= 0
        // The list that was open last time stays (All after a restart). Only if the wallpaper on the screen
        // is not in it, or nothing is in it any more, it opens on All, so that it opens on that wallpaper.
        const tag = filterTag
        const keep = tag === "" || (names.some(n => WallpaperStore.tagsOf(n).indexOf(tag) >= 0)
                                    && (!known || WallpaperStore.tagsOf(cur).indexOf(tag) >= 0))
        filterTag = keep ? tag : ""
        // (The list is new now.) Start on the wallpaper that is on the screen if it is listed, else the first.
        const i = wpModel.indexOfName(wpModel.current)
        setSelected(i >= 0 ? i : 0)
        // Only now: the glide is off until here, so the carousel starts in place instead of sliding.
        filterPending = false
    }

    // Lists another set. Nothing is applied: the selection goes to the wallpaper on the screen if it is
    // in the new list, else to the first (the picture in the middle then says it is not applied yet).
    function setFilter(tag) {
        if (tag === filterTag)
            return
        filterTag = tag
        followCurrent = false
        const i = wpModel.indexOfName(wpModel.current)
        setSelected(i >= 0 ? i : 0)
        wallpaperTimer.stop()
    }

    function cycleFilter(d) {
        const chips = filterChips
        let at = chips.findIndex(c => c.tag === filterTag)
        if (at < 0)
            at = 0
        setFilter(chips[(at + d + chips.length) % chips.length].tag)
    }

    // ---- favourite and tags of the selected wallpaper ---------------------------------------------

    readonly property var entryTags: entry ? WallpaperStore.tagsOf(entry.name) : []
    readonly property bool favourite: entry ? WallpaperStore.isFavourite(entry.name) : false

    function toggleFavourite() {
        if (entry)
            WallpaperStore.toggleFavourite(entry.name)
    }

    // Typing a tag for the selected wallpaper (T).
    property bool addingTag: false

    // What is typed in the tag field, and which of the existing tags offered below it is highlighted
    // (Up / Down; -1 for none). The offered tags are the ones some wallpaper has that this one does not,
    // narrowed by what is typed, so a tag that exists never has to be typed out.
    property string tagText: ""
    property int sugIndex: -1
    readonly property var tagSuggestions: WallpaperStore.suggestTags(wpModel.tagList, entryTags, tagText, 7)

    function startAddTag() {
        if (!entry)
            return
        tagText = ""
        sugIndex = -1
        addingTag = true
    }

    function finishAddTag(text) {
        if (entry && text.trim().length > 0)
            WallpaperStore.addTags(entry.name, text)
        addingTag = false
        tagText = ""
        sugIndex = -1
        keys.forceActiveFocus()
    }

    // Adds the offered tag `i` (and the complete tags typed before it); the field stays open for more.
    function pickSuggestion(i) {
        const s = tagSuggestions[i]
        if (!s || !entry)
            return
        const done = tagText.split(",").slice(0, -1)
        WallpaperStore.addTags(entry.name, done.concat([s.tag]).join(","))
        tagText = ""
        sugIndex = -1
    }

    // ---- the colours of the selected wallpaper ----------------------------------------------------

    readonly property var colors: ColorCache.colorsOf(entry)
    readonly property var choice: entry ? WallpaperStore.choiceOf(entry.name) : ({ index: 0, type: WallpaperStore.defaultType, mode: WallpaperStore.defaultMode })
    readonly property int colorIndex: colors ? Math.min(choice.index, colors.length - 1) : choice.index

    function pickColor(i) {
        if (!entry || !colors || i < 0 || i >= colors.length)
            return
        WallpaperStore.setChoice(entry.name, i, choice.type, choice.mode)
        colorTimer.restart()
    }

    // Previous / next colour (wraps round).
    function stepColor(d) {
        if (colors && colors.length > 0)
            pickColor((colorIndex + d + colors.length) % colors.length)
    }

    // ---- applying (always the latest request; one at a time) --------------------------------------

    // What was applied last, by file name (the wallpaper awww shows).
    property string appliedName: ""
    // The next job, { entry, wallpaper } (wallpaper false: only the colours).
    property var pending: null
    property string applyError: ""

    // The wallpaper in the middle is the one on the desktop (false right after opening on a favourites
    // list that does not contain it, or after another filter).
    readonly property bool applied: !!entry && entry.name === appliedName

    Timer {
        id: wallpaperTimer
        interval: 320
        onTriggered: root.request(true)
    }

    Timer {
        id: colorTimer
        interval: 120
        onTriggered: root.request(false)
    }

    // Applies the selected wallpaper. `fromSelection`: the selection has rested (nothing to do if it is
    // the wallpaper that is already applied, and a job still waiting for another one is dropped).
    // Otherwise a colour was chosen: only matugen runs, unless the picture still has to change.
    function request(fromSelection) {
        const e = entry
        if (!e)
            return
        const needsPicture = e.name !== appliedName
        if (fromSelection && !needsPicture) {
            pending = null
            return
        }
        const again = pending && pending.entry.name === e.name && pending.wallpaper
        pending = { entry: e, wallpaper: needsPicture || !!again }
        pump()
    }

    // Applies the one in the middle now (Space, Enter, a click on it) if it is not applied yet.
    function applyNow() {
        if (!entry || applied)
            return
        wallpaperTimer.stop()
        request(false)
    }

    function pump() {
        if (applier.running || !pending)
            return
        const job = pending
        pending = null
        const c = WallpaperStore.choiceOf(job.entry.name)
        applyError = ""
        const colours = ["--source-color-index", String(c.index), "-t", c.type, "-m", c.mode]
        if (job.wallpaper) {
            appliedName = job.entry.name
            applier.command = ["sh", "-c",
                'awww img -a "$1" && shift && matugen image "$@" >/dev/null',
                "sh", job.entry.path, job.entry.path].concat(colours)
        } else {
            applier.command = ["matugen", "image", job.entry.path].concat(colours)
        }
        applier.running = true
    }

    Process {
        id: applier
        stderr: StdioCollector {
            id: applyErr
        }
        onExited: (code, status) => {
            if (code !== 0)
                root.applyError = applyErr.text.trim() || ("Failed (exit code " + code + ")")
            wpModel.refreshCurrent()
            root.pump()
        }
    }

    // ---- opening and closing ----------------------------------------------------------------------

    function close() {
        root.shown = false
    }

    onShownChanged: {
        if (shown) {
            // One widget at a time: the others (and the bar's menus) close when this takes over.
            Widgets.closeOthers("wallpapers")
            followCurrent = true
            appliedName = wpModel.current
            addingTag = false
            // The list and selection are chosen once the files and the wallpaper on the screen are known.
            filterPending = true
            wpModel.refreshCurrent()
            ColorCache.enqueue(wpModel.entries)
            openFallback.restart()
            chooseInitialFilter(false)
            followCurrentNow()
            focusTimer.restart()
            keys.forceActiveFocus()
        } else {
            wheelCarry = 0
            addingTag = false
        }
    }

    // awww normally answers within a few ms; if it does not, open on what is known.
    Timer {
        id: openFallback
        interval: 500
        onTriggered: root.chooseInitialFilter(true)
    }

    // The compositor gives the keyboard to a new surface a moment after it appears.
    Timer {
        id: focusTimer
        interval: 60
        onTriggered: if (root.shown && !root.addingTag) keys.forceActiveFocus()
    }

    Connections {
        target: Hyprland

        function onFocusedWorkspaceChanged() {
            root.shown = false
        }
    }

    // ---- scrolling ---------------------------------------------------------------------------------

    // Wheel and touchpad deltas add up; every 120 is a step (one notch of a wheel). Down or right is next.
    property real wheelCarry: 0

    function onWheelDelta(dx, dy) {
        wheelCarry -= dx + dy
        while (wheelCarry >= 120) {
            wheelCarry -= 120
            step(1)
        }
        while (wheelCarry <= -120) {
            wheelCarry += 120
            step(-1)
        }
    }

    // ---- the picture -------------------------------------------------------------------------------

    readonly property real cardW: Math.round(width / 2)
    readonly property real cardH: Math.round(height / 2)
    readonly property real cornerRadius: 18

    // How the overlay looks (all adjustable here).
    // How much the desktop is darkened behind the pictures (0 = not at all).
    readonly property real dim: 0.22
    // The neighbours of the middle picture are almost as opaque as it; to keep the middle one the
    // centre of attention they are a little less saturated and flatter (-1..0; 0 = unchanged).
    readonly property real sideSaturation: -0.35
    readonly property real sideContrast: -0.2
    // The neighbours have the compositor's glass behind them (the Lucent plugin, as everywhere else: see
    // shared/glass/GLASS-WINDOWS.md), so that what shines through their translucent pictures is the desktop
    // blurred by `sideBlur` (sigma, logical px) and not the sharp desktop. Without the plugin, or with
    // Theme.glass / Theme.compositorGlass off, nothing is drawn behind them (the sharp desktop shows).
    readonly property bool sideGlass: true
    readonly property real sideBlur: 7
    // The backing of the bar and the hints over the desktop (so that they read over any window).
    readonly property color plateColor: Qt.rgba(0, 0, 0, 0.82)

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: true
        visible: root.shown || fade.opacity > 0.01

        Keys.onPressed: event => {
            // While a tag is being typed the field has the keys (it takes Enter and Esc itself).
            if (root.addingTag)
                return
            const k = event.key
            const ctrl = event.modifiers & Qt.ControlModifier
            const shift = event.modifiers & Qt.ShiftModifier
            if (k === Qt.Key_Escape || (k === Qt.Key_C && ctrl)) {
                root.close()
            } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                root.applyNow()
                root.close()
            } else if (k === Qt.Key_Space) {
                root.applyNow()
            } else if ((k === Qt.Key_Left || k === Qt.Key_Right) && shift) {
                root.stepColor(k === Qt.Key_Left ? -1 : 1)
            } else if (k === Qt.Key_Left || k === Qt.Key_H) {
                root.step(-1)
            } else if (k === Qt.Key_Right || k === Qt.Key_L) {
                root.step(1)
            } else if (k === Qt.Key_Home) {
                root.select(0)
            } else if (k === Qt.Key_End) {
                root.select(root.entries.length - 1)
            } else if (k >= Qt.Key_1 && k <= Qt.Key_5) {
                root.pickColor(k - Qt.Key_1)
            } else if (k === Qt.Key_Up) {
                root.stepColor(-1)
            } else if (k === Qt.Key_Down) {
                root.stepColor(1)
            } else if (k === Qt.Key_Tab || k === Qt.Key_Backtab) {
                root.cycleFilter(shift || k === Qt.Key_Backtab ? -1 : 1)
            } else if (k === Qt.Key_F) {
                root.toggleFavourite()
            } else if (k === Qt.Key_T) {
                root.startAddTag()
            } else {
                return
            }
            event.accepted = true
        }

        // Dims the desktop a little, so that the pictures stand out.
        Rectangle {
            id: fade
            anchors.fill: parent
            color: "black"
            opacity: root.shown ? root.dim : 0
            Behavior on opacity {
                NumberAnimation { duration: 180 }
            }
        }

        // A click anywhere that is not a picture closes it; the wheel scrolls from anywhere.
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
            onWheel: wheel => {
                root.onWheelDelta(wheel.angleDelta.x, wheel.angleDelta.y)
                wheel.accepted = true
            }
        }

        // The pictures. Only the ones near the middle load their image (the folder may be large).
        Item {
            id: stage
            anchors.fill: parent
            opacity: root.shown && !root.filterPending ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: 180 }
            }

            Repeater {
                model: root.entries.length

                delegate: Item {
                    id: card
                    required property int index

                    readonly property real off: index - root.pos
                    readonly property real a: Math.abs(off)
                    readonly property bool near: a < 3
                    readonly property var info: root.entries[index]

                    visible: near && !!info
                    width: root.cardW
                    height: root.cardH
                    // The neighbours sit behind the middle picture, smaller, and fade out.
                    x: stage.width / 2 - width / 2
                       + (off < 0 ? -1 : 1) * root.cardW * (a <= 1 ? a * 0.74 : 0.74 + (a - 1) * 0.30)
                    y: stage.height / 2 - height / 2
                    scale: Math.max(0.5, 1 - 0.32 * a)
                    // (The neighbours stay quite opaque, then fade out towards the edges.)
                    opacity: a <= 1 ? 1 - 0.08 * a : Math.max(0, 0.92 - 0.92 * (a - 1) / 1.9)
                    // 0 for the middle picture, 1 from the first neighbour on.
                    readonly property real side: Math.min(1, a)
                    z: 100 - a * 10

                    // The glass behind this picture. It is NOT a child of the card: the region it sends to the
                    // compositor is its own position and size (it ignores an ancestor's scale, and is only
                    // updated when its own geometry changes), so it sits in the stage and follows the card's
                    // drawn rectangle, which changes at every step of the glide. It fades with the card, and
                    // is not needed under the middle picture (opaque).
                    LucentGlass {
                        parent: stage
                        x: card.x + card.width * (1 - card.scale) / 2
                        y: card.y + card.height * (1 - card.scale) / 2
                        width: card.width * card.scale
                        height: card.height * card.scale
                        active: root.sideGlass && Theme.glass && Theme.compositorGlass && card.a > 0.15 && card.near
                        blurRadius: root.sideBlur
                        cornerRadius: root.cornerRadius * card.scale
                        glassOpacity: card.opacity
                    }

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: root.cornerRadius
                        color: Theme.surface

                        // The picture is not drawn itself: the effect draws it, less saturated and flatter
                        // the further it is from the middle.
                        Image {
                            id: picture
                            anchors.fill: parent
                            visible: false
                            source: card.near && card.info ? "file://" + card.info.path : ""
                            asynchronous: true
                            cache: true
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: Math.ceil(root.cardW * root.devicePixelRatio)
                        }

                        MultiEffect {
                            anchors.fill: parent
                            source: picture
                            saturation: root.sideSaturation * card.side
                            contrast: root.sideContrast * card.side
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: root.cornerRadius
                        color: "transparent"
                        border.width: card.a < 0.5 ? 2 : 1
                        border.color: card.a < 0.5 ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(1, 1, 1, 0.25)
                    }

                    // The one on the desktop now.
                    Rectangle {
                        visible: !!card.info && card.info.name === root.appliedName
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 14
                        width: nowLabel.implicitWidth + 20
                        height: 24
                        radius: 12
                        color: Theme.accent

                        CenteredText {
                            id: nowLabel
                            anchors.centerIn: parent
                            text: "✓ Current"
                            font.pixelSize: Theme.textSmall
                            font.bold: true
                            color: Theme.background
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (card.a >= 0.5)
                                root.select(card.index)
                            else
                                root.applyNow()
                        }
                        onWheel: wheel => {
                            root.onWheelDelta(wheel.angleDelta.x, wheel.angleDelta.y)
                            wheel.accepted = true
                        }
                    }
                }
            }

            // Over the middle picture (which it does not move with: the pictures glide under it): at the
            // top the star and the tags, at the bottom the name, the position in the list, and the colours.
            ClippingRectangle {
                id: plate
                visible: !!root.entry
                x: stage.width / 2 - width / 2
                y: stage.height / 2 - height / 2
                width: root.cardW
                height: root.cardH
                radius: root.cornerRadius
                color: "transparent"
                z: 1000

                // Top: the star and the tags.
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: root.addingTag ? 140 : 90
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.66) }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0) }
                    }
                }

                Row {
                    id: tagRow
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.top: parent.top
                    anchors.topMargin: 16
                    anchors.right: parent.right
                    anchors.rightMargin: 110
                    spacing: 8
                    height: 30
                    clip: true

                    // The star (F): the favourite tag.
                    Item {
                        width: 32
                        height: 30

                        Text {
                            anchors.centerIn: parent
                            text: root.favourite ? "★" : "☆"
                            color: root.favourite ? "#f5c542" : (starArea.containsMouse ? "white" : Qt.rgba(1, 1, 1, 0.75))
                            font.pixelSize: 26
                        }

                        MouseArea {
                            id: starArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleFavourite()
                        }
                    }

                    Repeater {
                        model: root.entryTags.filter(t => t !== WallpaperStore.favouriteTag)

                        delegate: TagChip {
                            required property string modelData
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData
                            removable: true
                            onRemoved: if (root.entry) WallpaperStore.removeTag(root.entry.name, modelData)
                            onClicked: root.setFilter(modelData)
                        }
                    }

                    // "+ tag": click or T. Becomes a text field.
                    TagChip {
                        visible: !root.addingTag
                        anchors.verticalCenter: parent.verticalCenter
                        text: "+ tag"
                        onClicked: root.startAddTag()
                    }

                    // The tag field exists only while a tag is being typed. (A hidden TextField that once had
                    // the focus stays the focus item of the key scope and then takes Escape and Ctrl+C, which
                    // a text field treats as "copy": the overlay could no longer be closed with them.)
                    Loader {
                        active: root.addingTag
                        anchors.verticalCenter: parent.verticalCenter

                        sourceComponent: TextField {
                            width: 220
                            height: 28
                            leftPadding: 12
                            rightPadding: 12
                            topPadding: 0
                            bottomPadding: 0
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            font.pixelSize: Theme.textSmall + 1
                            color: Theme.text
                            placeholderText: "new tag, or pick one below"
                            placeholderTextColor: Theme.textMuted

                            background: Rectangle {
                                radius: 14
                                color: Qt.rgba(0, 0, 0, 0.6)
                                border.width: 2
                                border.color: Theme.accent
                            }

                            Component.onCompleted: forceActiveFocus()

                            text: root.tagText
                            onTextEdited: {
                                root.tagText = text
                                root.sugIndex = -1
                            }

                            // Esc cancels; Down / Up highlight an existing tag; Enter adds the highlighted
                            // one (the field stays open), or what is typed (and closes it); Tab adds the
                            // highlighted one, or the first.
                            Keys.onPressed: event => {
                                const n = root.tagSuggestions.length
                                if (event.key === Qt.Key_Escape) {
                                    root.finishAddTag("")
                                } else if (event.key === Qt.Key_Down) {
                                    root.sugIndex = Math.min(root.sugIndex + 1, n - 1)
                                } else if (event.key === Qt.Key_Up) {
                                    root.sugIndex = Math.max(root.sugIndex - 1, -1)
                                } else if (event.key === Qt.Key_Tab) {
                                    if (n > 0)
                                        root.pickSuggestion(root.sugIndex >= 0 ? root.sugIndex : 0)
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    if (root.sugIndex >= 0)
                                        root.pickSuggestion(root.sugIndex)
                                    else
                                        root.finishAddTag(text)
                                } else {
                                    return
                                }
                                event.accepted = true
                            }
                        }
                    }
                }

                // The existing tags, to pick from while a tag is being typed: click one, or Down / Up and Enter,
                // or Tab for the first. (On a plate: it is over the picture.)
                Rectangle {
                    visible: root.addingTag && root.tagSuggestions.length > 0
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.top: tagRow.bottom
                    anchors.topMargin: 10
                    width: Math.min(parent.width - 40, suggestionRow.implicitWidth + 28)
                    height: 40
                    radius: height / 2
                    color: root.plateColor
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.14)
                    clip: true

                    Row {
                        id: suggestionRow
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        spacing: 6

                        CenteredText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "existing"
                            color: Qt.rgba(1, 1, 1, 0.6)
                            font.pixelSize: Theme.textSmall
                        }

                        Repeater {
                            model: root.tagSuggestions

                            delegate: SegmentChip {
                                required property var modelData
                                required property int index
                                anchors.verticalCenter: parent.verticalCenter
                                height: 32
                                text: modelData.tag
                                count: modelData.count
                                chosen: index === root.sugIndex
                                onClicked: root.pickSuggestion(index)
                            }
                        }
                    }
                }

                // Bottom: the name and the colours.
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 140
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0) }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.78) }
                    }
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 28
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 24
                    anchors.right: swatches.left
                    anchors.rightMargin: 20
                    spacing: 4

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: root.entry ? root.entry.base : ""
                        color: "white"
                        font.pixelSize: Theme.textLarge + 4
                        font.bold: true
                    }

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: root.entry
                            ? (root.selected + 1) + " / " + root.entries.length
                              + "  ·  " + root.choice.type.replace("scheme-", "").replace(/-/g, " ")
                              + "  ·  " + root.choice.mode
                              + (root.applyError ? "  ·  " + root.applyError
                                 : (applier.running || root.pending || wallpaperTimer.running ? "  ·  applying…"
                                    : (!root.applied ? "  ·  not applied: Space" : "")))
                            : ""
                        color: root.applyError ? Theme.red : Qt.rgba(1, 1, 1, 0.72)
                        font.pixelSize: Theme.textMedium
                    }
                }

                Row {
                    id: swatches
                    anchors.right: parent.right
                    anchors.rightMargin: 28
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 24
                    spacing: 12

                    Text {
                        visible: !root.colors
                        anchors.verticalCenter: parent.verticalCenter
                        text: "reading colours…"
                        color: Qt.rgba(1, 1, 1, 0.6)
                        font.pixelSize: Theme.textSmall
                    }

                    Repeater {
                        model: root.colors || []

                        delegate: Item {
                            id: sw
                            required property string modelData
                            required property int index
                            readonly property bool chosen: index === root.colorIndex

                            width: 46
                            height: 46

                            Rectangle {
                                anchors.centerIn: parent
                                width: swArea.containsMouse || sw.chosen ? 44 : 38
                                height: width
                                radius: width / 2
                                color: sw.modelData
                                border.width: sw.chosen ? 3 : 1
                                border.color: sw.chosen ? "white" : Qt.rgba(1, 1, 1, 0.35)
                                Behavior on width {
                                    NumberAnimation { duration: 90 }
                                }
                            }

                            MouseArea {
                                id: swArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.pickColor(sw.index)
                            }
                        }
                    }
                }
            }

            // Nothing to show: an empty favourites list, or a tag nobody has any more.
            Text {
                visible: root.entries.length === 0 && wpModel.entries.length > 0
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                text: root.filterTag === WallpaperStore.favouriteTag
                    ? "No favourites yet.\nPress Tab for all wallpapers, then F on one you like."
                    : "No wallpapers with this tag.\nPress Tab for another list."
                color: Qt.rgba(1, 1, 1, 0.8)
                font.pixelSize: Theme.textLarge
            }
        }

        // Which wallpapers are listed: the bar at the top of the screen (Tab). A segmented control on a dark
        // plate (so that it reads over whatever is on the desktop): the chips fill the plate's height, the
        // chosen one is solid, the others have no outline.
        Rectangle {
            id: filterPlate
            readonly property int pad: 4
            opacity: root.shown && !root.filterPending ? 1 : 0
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.max(24, Math.round(root.height / 4 - 74))
            width: filterBar.width + 2 * pad
            height: 40
            radius: height / 2
            color: root.plateColor
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.14)
            Behavior on opacity {
                NumberAnimation { duration: 180 }
            }

            ListView {
                id: filterBar
                anchors.centerIn: parent
                width: Math.min(root.width * 0.8, contentWidth)
                height: filterPlate.height - 2 * filterPlate.pad - 2
                orientation: ListView.Horizontal
                spacing: 2
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.filterChips

                // Keep the chosen chip in view.
                property int chosenIndex: Math.max(0, root.filterChips.findIndex(c => c.tag === root.filterTag))
                onChosenIndexChanged: positionViewAtIndex(chosenIndex, ListView.Contain)

                delegate: SegmentChip {
                    required property var modelData
                    text: modelData.label
                    count: modelData.count
                    chosen: modelData.tag === root.filterTag
                    height: filterBar.height
                    onClicked: root.setFilter(modelData.tag)
                }
            }
        }

        // What the keys are, on a dark plate (see the bar above).
        Rectangle {
            opacity: root.shown && !root.filterPending ? 1 : 0
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 24
            width: hints.implicitWidth + 40
            height: 36
            radius: height / 2
            color: root.plateColor
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.14)

            CenteredText {
                id: hints
                anchors.centerIn: parent
                text: "\u2190 \u2192 wallpaper     \u21E7\u2190 \u21E7\u2192 colour     Tab list     F favourite     T tag     Esc close"
                color: Qt.rgba(1, 1, 1, 0.85)
                font.pixelSize: Theme.textSmall
            }
        }
    }
}
