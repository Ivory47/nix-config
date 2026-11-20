import QtQuick
import qs.shared
import qs.controls
import qs.fields

// A collapsed section of ThemeSchema (kind "collapsed": { id, title, note, items }): a header row (click to open
// or close; closed, it shows how many of its settings were changed), then its settings with a line on the left
// that closes it again. `page` is the ThemePage (which are open, the fields to scroll to). Set `width`.
Collapsible {
    id: group

    required property var page
    required property var modelData

    open: !!page.openGroups[modelData.id]
    title: modelData.title
    note: modelData.note || ""
    changed: page.changedIn(modelData.items)
    onToggled: open => page.setGroupOpen(modelData.id, open)

    Repeater {
        model: group.modelData.items

        delegate: Column {
            id: groupItem
            required property var modelData
            width: parent.width

            // A gap between clusters of settings (schema `gapBefore`).
            Item { width: 1; height: groupItem.modelData.gapBefore ? Theme.spacingLarge : 0 }

            SettingField {
                id: groupField
                width: parent.width
                spec: groupItem.modelData

                Component.onCompleted: group.page.fields[groupItem.modelData.key] = groupField
            }
        }
    }
}
