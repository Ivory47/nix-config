import QtQuick
import qs.shared
import qs.controls
import qs.core
import qs.fields

// A list of settings of a ThemePage section, under an optional small title (ThemeSchema `blocks`). A setting
// with `showIf` is only shown while that other setting has that value (the block's own `showIf` hides all of
// it); `gapBefore` leaves a gap above it.
// `page` is the ThemePage (fields to scroll to). Set `width`.
Column {
    id: root

    required property var page
    property string title: ""
    property var items: []
    property var showIf: null

    visible: !showIf || ThemeStore.value(showIf.key) === showIf.is

    BlockTitle {
        visible: root.title.length > 0
        text: root.title
    }

    Repeater {
        model: root.items

        delegate: Column {
            id: entry
            required property var modelData
            readonly property var cond: modelData.showIf
            width: root.width
            visible: !cond || ThemeStore.value(cond.key) === cond.is

            Item { width: 1; height: entry.modelData.gapBefore ? Theme.spacingLarge : 0 }

            SettingField {
                id: field
                width: parent.width
                spec: entry.modelData

                Component.onCompleted: if (entry.modelData.key) root.page.fields[entry.modelData.key] = field
            }
        }
    }
}
