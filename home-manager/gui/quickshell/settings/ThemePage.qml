import QtQuick
import qs.shared

// The page of one Theme category of the settings app (ThemeSchema `categories`, chosen by `catId`): a header
// (name, description, the category's buttons and "Reset page") over its sections. Changing a value writes it
// to the settings app's file (see ThemeStore) and every shell follows; a reset arrow brings back the
// default from ThemeDefaults.qml.
Item {
    id: root

    required property string catId
    readonly property var category: SettingsIndex.categories[SettingsIndex.indexOf(catId)]
    readonly property var sections: category.sections
    readonly property var pageKeys: SettingsIndex.keysOf(catId)

    ThemeActions {
        id: themeActions
    }

    // key -> the field of that setting, to scroll to it (set by the fields themselves).
    property var fields: ({})

    // The collapsed sections (kind "collapsed"): which are open (id -> true). All start closed.
    property var openGroups: ({})
    // key -> where it is: { group (collapsed section id), showIf }.
    readonly property var placeOf: {
        const out = {}
        for (const s of sections)
            for (const { item, showIf, group } of ThemeSchema.flatten(s))
                out[item.key] = {
                    group: s.kind === "collapsed" ? s.id : group,
                    showIf: showIf
                }
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

    // How many of these settings were changed from their defaults (shown on a closed group, so that a
    // change cannot hide in it).
    function changedIn(items) {
        let n = 0
        for (const item of items)
            if (ThemeStore.isSet(item.key))
                n++
        return n
    }

    // Scrolls the page so that the setting is near the top, and outlines it for a moment. A setting in a
    // closed group opens the group (and waits for the page to be laid out again); one hidden by `showIf`
    // shows the setting it depends on instead.
    function scrollTo(key, gentle) {
        const p = placeOf[key]
        if (!p)
            return
        // Hidden (a widget that follows the default look): its choice row instead, nothing to open.
        if (p.showIf && Theme.value(p.showIf.key) !== p.showIf.is) {
            _scrollNow(p.showIf.key, gentle)
            return
        }
        if (p.group && !openGroups[p.group]) {
            setGroupOpen(p.group, true)
            scrollTimer.key = key
            scrollTimer.gentle = !!gentle
            scrollTimer.restart()
            return
        }
        _scrollNow(key, gentle)
    }

    function _scrollNow(key, gentle) {
        const f = fields[key]
        if (!f)
            return
        flick.show(f, gentle)
        f.flash()
    }

    Timer {
        id: scrollTimer
        property string key: ""
        property bool gentle: false
        interval: 60
        onTriggered: root._scrollNow(key, gentle)
    }

    PageHeader {
        id: header
        width: parent.width
        title: root.category.name
        description: root.category.description || ""

        Repeater {
            model: root.category.actions || []

            delegate: ActionButton {
                required property string modelData
                readonly property var action: themeActions.actions[modelData]
                text: action.label
                icon: action.icon || ""
                busy: action.busy
                busyText: action.busyText
                onClicked: action.run()
            }
        }

        ActionButton {
            text: "Reset page"
            active: root.pageKeys.some(k => ThemeStore.isSet(k))
            onClicked: ThemeStore.resetKeys(root.pageKeys)
        }
    }

    SettingsPage {
        id: flick
        anchors.top: header.bottom
        anchors.topMargin: Theme.spacingMedium
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 0

        Repeater {
            model: root.sections

            delegate: ThemeSection {
                page: root
                width: flick.column.width
            }
        }
    }
}
