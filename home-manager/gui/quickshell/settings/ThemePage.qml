import QtQuick
import qs.shared

// Every value of Theme.qml, in groups. Changing one writes it to the settings app's file (see
// ThemeStore) and every shell follows. The reset arrow next to a value brings back the default
// from ThemeDefaults.qml.
Item {
    id: root

    readonly property var sections: ThemeSchema.sections

    ThemeActions {
        id: themeActions
    }
    readonly property var actions: themeActions.actions

    // key -> the field of that setting, to scroll to it.
    property var fields: ({})

    // The collapsible groups (ThemeSchema `groups`): which are open (id -> true), and which group a
    // setting is in (key -> id). All start closed.
    property var openGroups: ({})
    readonly property var groupOf: {
        const out = {}
        for (const s of sections)
            for (const g of (s.groups || []))
                for (const item of g.items)
                    out[item.key] = g.id
        return out
    }

    function setGroupOpen(id, open) {
        const next = Object.assign({}, openGroups)
        if (open)
            next[id] = true
        else
            delete next[id]
        openGroups = next
    }

    // How many of the settings of a group were changed from their defaults (shown on a closed group,
    // so that a change cannot hide in it).
    function changedIn(items) {
        let n = 0
        for (const item of items)
            if (ThemeStore.isSet(item.key))
                n++
        return n
    }

    // Scrolls the page so that the setting is near the top, and outlines it for a moment. A setting in
    // a closed group opens the group first (and waits for the page to be laid out again).
    function scrollTo(key) {
        const g = groupOf[key]
        if (g && !openGroups[g]) {
            setGroupOpen(g, true)
            scrollTimer.key = key
            scrollTimer.restart()
            return
        }
        _scrollNow(key)
    }

    function _scrollNow(key) {
        const f = fields[key]
        if (!f)
            return
        flick.stopGlide()
        flick.contentY = flick.clampContentY(f.mapToItem(flick.contentItem, 0, 0).y - 70)
        f.flash()
    }

    Timer {
        id: scrollTimer
        property string key: ""
        interval: 60
        onTriggered: root._scrollNow(key)
    }

    SettingsPage {
        id: flick
        anchors.fill: parent
        spacing: 0

        Repeater {
            model: root.sections

            delegate: Column {
                id: section
                required property var modelData
                required property int index
                width: flick.column.width

                // The section title.
                Item {
                    width: parent.width
                    height: sectionTitle.implicitHeight

                    Text {
                        id: sectionTitle
                        topPadding: section.index === 0 ? 0 : Theme.spacingLarge
                        bottomPadding: 2
                        text: section.modelData.title
                        color: Theme.accent
                        font.pixelSize: Theme.textLarge - 2
                        font.bold: true
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.surfaceAlt
                }

                Repeater {
                    model: section.modelData.items

                    delegate: SettingField {
                        id: field
                        required property var modelData
                        width: section.width
                        spec: modelData

                        Component.onCompleted: root.fields[modelData.key] = field
                    }
                }

                // The section's collapsible groups: a header row (click to open or close; closed
                // shows how many of its settings were changed), then its settings.
                Repeater {
                    model: section.modelData.groups || []

                    delegate: ThemeGroup {
                        page: root
                        width: section.width
                    }

                }

                // The section's action (ThemeSchema `button`) as a row of its own, like a
                // setting: label and note on the left, the button where the controls are.
                SectionAction {
                    action: root.actions[section.modelData.button]
                    width: parent.width
                }
            }
        }

        Item { width: 1; height: Theme.spacingLarge }

        Rectangle {
            id: resetAll
            width: 150
            height: 32
            radius: Theme.radiusSmall
            color: "transparent"
            border.width: 1
            border.color: resetAllArea.containsMouse ? Theme.red : Theme.surfaceAlt
            opacity: Object.keys(ThemeStore.values).length > 0 ? 1 : 0.4

            CenteredText {
                anchors.centerIn: parent
                text: "Reset all to defaults"
                color: Theme.text
                font.pixelSize: Theme.textSmall
            }

            MouseArea {
                id: resetAllArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ThemeStore.resetAll()
            }
        }
    }
}
