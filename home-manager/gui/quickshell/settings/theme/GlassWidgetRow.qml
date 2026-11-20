import QtQuick
import qs.shared
import qs.controls
import qs.core

// One widget (or group of widgets) of the Glass page's "widgets" section (ThemeSchema `widget()`): a line with
// its name and the choice Default look | Own look. With its own look it can open (click the line) to show
// that look in place, indented with a line on the left that closes it again; closed, it shows how many of
// its values it changes. Picking Own opens it. A value it does not set follows the default look.
// `page` is the ThemePage (open state, fields to scroll to, counts). Set `width`.
Collapsible {
    id: row

    required property var page
    required property var widget        // { id, title, note, items: [the choice], blocks }
    readonly property var choice: widget.items[0]
    readonly property bool own: ThemeStore.value(choice.key) === "own"

    // Only an own look opens; h / l pick Default / Own look (Own opens it), Enter opens or closes an own
    // look (or picks Own), r goes back to the default look.
    expandable: own
    open: own && !!page.openGroups[widget.id]
    title: widget.title
    note: widget.note || ""
    boldTitle: false
    headerHeight: 52
    bodyBottom: Theme.spacingSmall
    toggleOnKeys: false
    rightItem: choiceControl
    changed: {
        let n = 0
        for (const b of widget.blocks)
            n += page.changedIn(b.items)
        return n
    }
    onToggled: open => page.setGroupOpen(widget.id, open)
    onAdjusted: dir => choiceControl.picked(dir > 0 ? "own" : "default")
    onActivated: {
        if (own)
            page.setGroupOpen(widget.id, !open)
        else
            choiceControl.picked("own")
    }
    function navReset() { ThemeStore.reset(choice.key) }

    // Marked for a moment when found (the page's scrollTo of its choice).
    function flash() { frame.flash() }
    Component.onCompleted: page.fields[choice.key] = row

    headerContent: [
        Segmented {
            id: choiceControl
            anchors.right: parent.right
            // (Where the controls of the rows end: the reset arrows' column is to the right.)
            anchors.rightMargin: 22 + Theme.spacingSmall
            anchors.verticalCenter: parent.verticalCenter
            width: 240
            stretch: true
            segmentHeight: 28
            options: row.choice.options
            current: ThemeStore.value(row.choice.key)
            onPicked: id => {
                ThemeStore.set(row.choice.key, id)
                if (id === "own")
                    row.page.setGroupOpen(row.widget.id, true)
            }
        },
        FlashFrame { id: frame }
    ]

    Repeater {
        model: row.widget.blocks

        delegate: SettingsBlock {
            required property var modelData
            width: parent.width
            page: row.page
            title: modelData.title || ""
            items: modelData.items
        }
    }
}
