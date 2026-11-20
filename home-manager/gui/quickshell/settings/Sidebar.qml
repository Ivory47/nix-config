import QtQuick
import qs.shared
import qs.controls
import qs.core

// The left side of the settings app: the title, the categories under their top-level headings (the list
// the glass highlights, `categoryList`), and Undo / Redo / Reset all at the bottom. The view (SettingsView)
// tells it whether to show search counts and the key hint, and hears of a new category (`categoryChanged`).
Item {
    id: sidebar

    width: 190

    property bool glassOn: true
    property bool searching: false
    // category id -> how many settings match the search
    property var matchCounts: ({})
    property bool showKeyHint: false
    property string keyHint: ""
    // The category row under the mouse, if any.
    property Item hoveredItem: null
    readonly property alias categoryList: categoryList
    signal categoryChanged()

    // Vim keys: where the list of keys is.
    CenteredText {
        visible: sidebar.showKeyHint
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingMedium
        anchors.verticalCenter: title.verticalCenter
        text: sidebar.keyHint
        color: Theme.textMuted
        font.pixelSize: Theme.textSmall
    }

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
        anchors.bottom: sidebarActions.top
        anchors.bottomMargin: Theme.spacingSmall
        width: parent.width
        spacing: Theme.spacingSmall
        clip: true
        currentIndex: 0

        // Another category: the view starts a fresh search.
        onCurrentIndexChanged: sidebar.categoryChanged()

        // The categories under their top-level headings (ListView sections: the headings are not
        // rows, so the current row and the glass highlight are unaffected). A ListModel, because
        // sections need a role; filled once from SettingsIndex.categories (already in group order).
        model: ListModel {
            id: categoryModel
            Component.onCompleted: {
                for (const c of SettingsIndex.categories)
                    append({ catId: c.id, name: c.name, icon: c.icon, groupName: SettingsIndex.groupName(c.group) })
            }
        }

        section.property: "groupName"
        section.delegate: BlockTitle {
            required property string section
            width: categoryList.width
            leftPadding: Theme.spacingMedium
            topPadding: Theme.spacingLarge
            bottomPadding: Theme.spacingSmall
            text: section
        }

        delegate: Item {
            id: cat
            required property string catId
            required property string name
            required property string icon
            required property int index
            readonly property bool hovered: catArea.containsMouse
            // Something on its page differs from the defaults.
            readonly property bool changed: SettingsIndex.keysOf(catId).some(k => ThemeStore.isSet(k))

            width: categoryList.width
            height: 44
            // The keyboard cursor (KeyNav) on the highlight's frame: the list clips what is outside.
            readonly property var navFrame: ({ x: 0, y: 0, width: width, height: height, radius: Theme.radiusMedium })

            // The glass draws the highlight of the selected and the hovered row; a plain fill
            // only when there is no glass.
            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusMedium
                color: (!sidebar.glassOn && (cat.index === categoryList.currentIndex || cat.hovered))
                    ? Theme.surface : "transparent"
            }

            onHoveredChanged: {
                if (hovered)
                    sidebar.hoveredItem = cat
                else if (sidebar.hoveredItem === cat)
                    sidebar.hoveredItem = null
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingMedium
                spacing: Theme.spacingMedium

                Text {
                    text: cat.icon
                    color: Theme.text
                    font.pixelSize: Theme.textLarge - 2
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: cat.name
                    color: Theme.text
                    font.pixelSize: Theme.textMedium
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // While searching: how many settings of this category match.
            Rectangle {
                visible: cat.changed && !sidebar.searching
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingMedium + 2
                anchors.verticalCenter: parent.verticalCenter
                width: 7
                height: 7
                radius: 3.5
                color: Theme.accent
            }

            Text {
                visible: sidebar.searching
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingMedium
                anchors.verticalCenter: parent.verticalCenter
                text: sidebar.matchCounts[cat.catId] || 0
                color: (sidebar.matchCounts[cat.catId] || 0) > 0 ? Theme.textSecondary : Theme.textMuted
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

    Column {
        id: sidebarActions
        anchors.bottom: parent.bottom
        x: Theme.spacingSmall
        spacing: Theme.spacingSmall

        // Every change of the app, on any page (SettingsHistory); Ctrl+Z and Ctrl+Shift+Z do the same.
        Row {
            spacing: Theme.spacingSmall

            ActionButton {
                text: "Undo"
                active: SettingsHistory.canUndo
                onClicked: SettingsHistory.undo()
            }
            ActionButton {
                text: "Redo"
                active: SettingsHistory.canRedo
                onClicked: SettingsHistory.redo()
            }
        }

        // Resets every Theme value (all pages; not the window rules).
        ActionButton {
            id: resetAll
            text: "Reset all to defaults"
            active: Object.keys(ThemeStore.values).length > 0
            onClicked: ThemeStore.resetAll()
        }
    }
}
