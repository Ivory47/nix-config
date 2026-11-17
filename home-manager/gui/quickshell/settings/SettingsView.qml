import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.shared

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
    // The category row under the mouse, if any.
    property Item hoveredItem: null
    readonly property alias searchField: searchField
    readonly property alias categoryList: categoryList
    signal closeRequested()

    // The search: what is typed, and whether it is limited to the selected category (otherwise
    // the selected category's results come first and the others follow).
    readonly property string query: searchField.text.trim()
    readonly property bool searching: query.length > 0
    property bool onlyThis: false
    readonly property var matchCounts: SettingsIndex.counts(query)
    readonly property string currentCategoryId: SettingsIndex.categories[categoryList.currentIndex]?.id ?? ""

    // "Show in page": opens the category, ends the search and scrolls to the setting.
    function jumpTo(catId, key) {
        const idx = SettingsIndex.indexOf(catId)
        if (idx < 0)
            return
        categoryList.currentIndex = idx
        searchField.text = ""
        searchField.focus = false
        root.forceActiveFocus()
        Qt.callLater(() => {
            const page = pages.children[idx]
            if (page && page.scrollTo)
                page.scrollTo(key)
        })
    }

    // A fresh start: no search, and no cursor in the empty field.
    function reset() {
        searchField.text = ""
        searchField.focus = false
    }

    // Only keys that the focused item did not use arrive here. A text field (a hex value,
    // the search field) uses every printable key, so typing a value never starts a
    // search; with nothing like that focused, a printable key goes to the search field
    // (as in Nautilus).
    Keys.onPressed: event => {
        const mods = event.modifiers
        const altGr = (mods & Qt.ControlModifier) && (mods & Qt.AltModifier)
        const printable = event.text.length > 0
            && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127
            && !(mods & Qt.MetaModifier)
            && (altGr || !(mods & (Qt.ControlModifier | Qt.AltModifier)))

        if (event.key === Qt.Key_Escape) {
            // First the search, then the window.
            if (searchField.text.length > 0) {
                searchField.text = ""
                // (Typing still goes to the search; there is just no blinking cursor.)
                searchField.focus = false
            } else {
                root.closeRequested()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_C && (mods & Qt.ControlModifier)) {
            root.closeRequested()
            event.accepted = true
        } else if (event.key === Qt.Key_Tab && root.searching && scopeChip.visible) {
            root.onlyThis = !root.onlyThis
            event.accepted = true
        } else if (printable && !(event.text === " " && searchField.text.length === 0)) {
            searchField.forceActiveFocus()
            searchField.insert(searchField.length, event.text)
            event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            categoryList.currentIndex = Math.min(categoryList.currentIndex + 1, categoryList.count - 1)
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            categoryList.currentIndex = Math.max(categoryList.currentIndex - 1, 0)
            event.accepted = true
        }
    }

    Item {
        id: sidebar
        x: Theme.spacingLarge
        y: Theme.spacingLarge
        width: 190
        height: parent.height - 2 * Theme.spacingLarge

        Text {
            id: title
            text: "Settings"
            color: Theme.text
            font.pixelSize: Theme.textLarge
            font.bold: true
            height: 50
            verticalAlignment: Text.AlignVCenter
            leftPadding: Theme.spacingMedium
        }

        ListView {
            id: categoryList
            anchors.top: title.bottom
            anchors.topMargin: Theme.spacingSmall
            anchors.bottom: parent.bottom
            width: parent.width
            spacing: Theme.spacingSmall
            clip: true
            currentIndex: 0

            // Another category: a fresh search.
            onCurrentIndexChanged: {
                searchField.text = ""
                searchField.focus = false
                root.onlyThis = false
            }

            model: SettingsIndex.categories

            delegate: Item {
                id: cat
                required property var modelData
                required property int index
                readonly property bool hovered: catArea.containsMouse

                width: categoryList.width
                height: 44

                // The glass draws the highlight of the selected and the hovered row; a plain fill
                // only when there is no glass.
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusMedium
                    color: (!root.glassOn && (cat.index === categoryList.currentIndex || cat.hovered))
                        ? Theme.surface : "transparent"
                }

                onHoveredChanged: {
                    if (hovered)
                        root.hoveredItem = cat
                    else if (root.hoveredItem === cat)
                        root.hoveredItem = null
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingMedium
                    spacing: Theme.spacingMedium

                    Text {
                        text: cat.modelData.icon
                        color: Theme.text
                        font.pixelSize: Theme.textLarge - 2
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: cat.modelData.name
                        color: Theme.text
                        font.pixelSize: Theme.textMedium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // While searching: how many settings of this category match.
                Text {
                    visible: root.searching
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingMedium
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.matchCounts[cat.modelData.id] || 0
                    color: (root.matchCounts[cat.modelData.id] || 0) > 0 ? Theme.textSecondary : Theme.textMuted
                    font.pixelSize: Theme.textSmall
                }

                MouseArea {
                    id: catArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: categoryList.currentIndex = cat.index
                }
            }
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
            // The text and cursor sat a little low next to the icon: the bottom padding
            // is larger than the top, which moves the line up by half the difference.
            topPadding: 0
            bottomPadding: 5
            verticalAlignment: TextInput.AlignVCenter
            font.pixelSize: Theme.textMedium
            color: Theme.text
            // Not focused: only the icon. Focused: the hint (and the cursor).
            placeholderText: activeFocus ? "Search settings…" : ""
            placeholderTextColor: Theme.textMuted
            selectByMouse: true

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

            Text {
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

            ThemePage {}
            HyprlandPage {}
        }

        SearchResults {
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
            mouse.accepted = false
        }
    }
}
