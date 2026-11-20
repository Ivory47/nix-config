import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.shared
import qs.controls
import qs.core
import qs.hyprland
import qs.keys
import qs.theme

// The content of the settings app: categories on the left, the search field and the page of the
// chosen category (or the search results) on the right. It has no window of its own: it is shown
// by one of two hosts, which also draw the glass behind it:
//  - Settings.qml: the full-screen overlay (GlassPopup, with the veil over the desktop);
//  - SettingsWindow.qml: a normal window (FloatingWindow, compositor glass).
// The hosts' glass draws the highlights of the search field and the selected / hovered category
// (`searchField`, `categoryList`, `hoveredItem`); with `glassOn` false (no glass) they are plain fills.
// Ask for closing with `closeRequested()` (Esc, Ctrl+C): the host decides what that means.
FocusScope {
    id: root
    focus: true

    // False when the host has no glass behind this: plain fills for the highlights then.
    property bool glassOn: true
    // The category row under the mouse, if any (the Sidebar's).
    readonly property alias hoveredItem: sidebar.hoveredItem
    readonly property alias searchField: searchField
    readonly property alias categoryList: sidebar.categoryList
    // For the keyboard (KeyNav): the search results (the pages: pageAt).
    readonly property alias results: results
    signal closeRequested()

    // The search: what is typed, and whether it is limited to the selected category (otherwise
    // the selected category's results come first and the others follow).
    readonly property string query: searchField.text.trim()
    readonly property bool searching: query.length > 0
    property bool onlyThis: false
    readonly property var matchCounts: SettingsIndex.counts(query)
    readonly property string currentCategoryId: SettingsIndex.categories[categoryList.currentIndex]?.id ?? ""

    // "Show in page": opens the category, ends the search and scrolls to the setting.
    // A link row (LinkField) asks for a jump through the index.
    Connections {
        target: SettingsIndex
        function onJumpRequested(catId, key) { root.jumpTo(catId, key) }
    }

    // An undo or redo shows what it changed: the page, then the setting (scrolled to only if it was out
    // of view).
    Connections {
        target: SettingsHistory
        function onRevealRequested(catId, key) { root.jumpTo(catId, key, true) }
    }

    // The page (an Item) of the category at this index in the sidebar's list.
    function pageAt(index) {
        return pageRepeater.itemAt(index)?.item ?? null
    }

    function jumpTo(catId, key, gentle) {
        const idx = SettingsIndex.indexOf(catId)
        if (idx < 0)
            return
        categoryList.currentIndex = idx
        searchField.text = ""
        searchField.focus = false
        root.forceActiveFocus()
        Qt.callLater(() => {
            const page = pageAt(idx)
            if (page && page.scrollTo)
                page.scrollTo(key, !!gentle)
        })
        nav.placeAt(idx, key)
    }

    // A fresh start: no search, and no cursor in the empty field.
    function reset() {
        searchField.text = ""
        searchField.focus = false
        nav.reset()
    }

    // The keys come here again (out of a text field). The field and every FocusScope between it and the view
    // (a Loader is one) must give up their focus first: a FocusScope's forceActiveFocus hands the focus to
    // its focused child, so one left with focus would take it back (the colour editor's Loader did).
    function takeFocus() {
        for (let f = Window.activeFocusItem; f && f !== root; f = f.parent)
            f.focus = false
        root.forceActiveFocus()
    }

    function clearSearch() {
        searchField.text = ""
        searchField.focus = false
    }

    function toggleOnlyThis() {
        if (scopeChip.visible)
            root.onlyThis = !root.onlyThis
    }

    // The keyboard: KeyNav (Settings app > Keyboard: vim keys, or classic = type to search).
    Keys.onPressed: event => nav.handle(event)

    KeyNav {
        id: nav
        view: root
    }

    Sidebar {
        id: sidebar
        x: Theme.spacingLarge
        y: Theme.spacingLarge
        height: parent.height - 2 * Theme.spacingLarge
        glassOn: root.glassOn
        searching: root.searching
        matchCounts: root.matchCounts
        showKeyHint: nav.vim
        keyHint: nav.keyHint
        // Another category: a fresh search.
        onCategoryChanged: {
            searchField.text = ""
            searchField.focus = false
            root.onlyThis = false
        }
    }

    Rectangle {
        id: divider
        x: sidebar.x + sidebar.width + Theme.spacingMedium
        y: Theme.spacingLarge
        width: 1
        height: parent.height - 2 * Theme.spacingLarge
        color: Theme.surfaceAlt
    }

    // The search field above the page. Its highlight is drawn by the glass (searchField is the
    // GlassListPanel's `field`), so its background is transparent.
    Item {
        id: searchBar
        x: divider.x + 1 + Theme.spacingLarge
        y: Theme.spacingLarge
        width: parent.width - x - Theme.spacingLarge
        height: 44

        TextField {
            id: searchField
            anchors.left: parent.left
            anchors.right: scopeChip.visible ? scopeChip.left : parent.right
            anchors.rightMargin: scopeChip.visible ? Theme.spacingSmall : 0
            height: parent.height
            // Room for the search icon.
            leftPadding: Theme.spacingMedium + 30
            rightPadding: Theme.spacingMedium
            // Equal paddings: the capital letters' middle is then level with the icon's
            // (measured in a screenshot: 51 and 51-51.5 px; a bottom padding of 5 put the
            // text and the placeholder about 3 px too high).
            topPadding: 0
            bottomPadding: 0
            verticalAlignment: TextInput.AlignVCenter
            font.pixelSize: Theme.textMedium
            color: Theme.text
            // Not focused: only the icon. Focused: the hint (and the cursor).
            placeholderText: activeFocus ? "Search settings…" : ""
            placeholderTextColor: Theme.textMuted
            selectByMouse: true
            // Vim keys: leaving the field and Tab first (FieldKeys); Enter goes into the results.
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: event => FieldKeys.press(event, searchField)
            onAccepted: {
                if (!nav.vim)
                    return
                root.takeFocus()
                if (root.searching)
                    nav.enterPage()
            }

            background: Rectangle {
                radius: Theme.radiusMedium
                color: "transparent" // drawn by the glass (hlRect0)
            }
        }

        // The search icon (a magnifying glass).
        Text {
            x: Theme.spacingMedium
            anchors.verticalCenter: parent.verticalCenter
            text: "\uDB80\uDF49"
            color: searchField.activeFocus ? Theme.text : Theme.textMuted
            font.pixelSize: Theme.textLarge - 2
        }

        // Limits the results to the selected category (Tab). Only with more than one.
        Rectangle {
            id: scopeChip
            visible: root.searching && SettingsIndex.categories.length > 1
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: chipText.implicitWidth + 20
            height: 28
            radius: Theme.radiusMedium
            color: root.onlyThis ? Theme.accent : "transparent"
            border.width: 1
            border.color: root.onlyThis ? Theme.accent : Theme.surfaceAlt

            CenteredText {
                id: chipText
                anchors.centerIn: parent
                text: "Only in " + (SettingsIndex.categories[categoryList.currentIndex]?.name ?? "")
                color: root.onlyThis ? Theme.background : Theme.textSecondary
                font.pixelSize: Theme.textSmall
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.onlyThis = !root.onlyThis
            }
        }
    }

    // The pages (one per category) or, while searching, the results.
    Item {
        id: content
        x: searchBar.x
        y: searchBar.y + searchBar.height + Theme.spacingMedium
        width: searchBar.width
        height: parent.height - y - Theme.spacingLarge

        StackLayout {
            id: pages
            anchors.fill: parent
            visible: !root.searching
            currentIndex: categoryList.currentIndex

            // One page per category, in the order of SettingsIndex.categories (the sidebar's order).
            Repeater {
                id: pageRepeater
                model: SettingsIndex.categories

                Loader {
                    id: pageLoader
                    required property var modelData
                    sourceComponent: modelData.id === "windowRules" ? rulesPage : themePage

                    Component { id: themePage; ThemePage { catId: pageLoader.modelData.id } }
                    Component { id: rulesPage; HyprlandPage {} }
                }
            }
        }

        SearchResults {
            id: results
            anchors.fill: parent
            visible: root.searching
            query: root.query
            priorityId: root.currentCategoryId
            onlyPriority: root.onlyThis
            onJump: (catId, key) => root.jumpTo(catId, key)
        }
    }

    // A click anywhere else in the panel takes the focus, and with it the blinking cursor,
    // out of the search field (typing still goes to the search, see Keys.onPressed). It is
    // an item above everything that looks at the press and does not accept it, so the
    // press goes on to whatever is under it (the scrolling lists below would otherwise take
    // it before a handler on a parent saw it).
    MouseArea {
        anchors.fill: parent
        z: 10000
        onPressed: mouse => {
            // Only while nothing is typed: with a search going on, the field keeps the focus.
            const p = searchField.mapFromItem(root, mouse.x, mouse.y)
            if (searchField.text.length === 0 && !searchField.contains(p))
                searchField.focus = false
            nav.pressedAt(mouse.x, mouse.y)
            mouse.accepted = false
        }
    }

    // Moving the mouse hides the keyboard cursor (the next key shows it again). Only a real move: items
    // scrolling under a still pointer send hover events too.
    HoverHandler {
        property point last: Qt.point(-1, -1)
        onPointChanged: {
            const p = point.scenePosition
            if (Math.abs(p.x - last.x) + Math.abs(p.y - last.y) > 2) {
                if (last.x >= 0)
                    nav.shown = false
                last = p
            }
        }
    }

    // The list of the vim keys (?).
    KeyHelp {
        anchors.centerIn: content
        visible: nav.helpOpen
        z: 9000
    }
}
