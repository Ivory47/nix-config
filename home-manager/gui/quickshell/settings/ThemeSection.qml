import QtQuick
import qs.shared

// One section of a ThemePage (ThemeSchema: { id, title, note, kind, ... }): the accent title with a line
// under it, then the settings drawn by `kind` (list, colors, table; "collapsed" is a ThemeGroup with
// its own header instead). `page` is the ThemePage. Set `width`.
Column {
    id: sec

    required property var page
    required property var modelData
    required property int index

    readonly property string kind: modelData.kind || "list"

    // Room above every section but the first.
    Item { width: 1; height: sec.index === 0 ? 0 : Theme.spacingLarge }

    Text {
        visible: sec.kind !== "collapsed"
        bottomPadding: 2
        text: sec.modelData.title
        color: Theme.accent
        font.pixelSize: Theme.textLarge - 2
        font.bold: true
    }

    Rectangle {
        visible: sec.kind !== "collapsed"
        width: parent.width
        height: 1
        color: Theme.surfaceAlt
    }

    // A note under the title.
    Text {
        readonly property string note: sec.kind === "collapsed" ? "" : (sec.modelData.note || "")
        visible: note.length > 0
        width: parent.width
        topPadding: 4
        wrapMode: Text.WordWrap
        text: note
        color: Theme.textMuted
        font.pixelSize: Theme.textSmall - 1
    }

    // list: the items, then the titled blocks.
    Loader {
        active: sec.kind === "list"
        visible: active
        width: parent.width
        sourceComponent: Column {
            SettingsBlock {
                width: parent.width
                page: sec.page
                items: sec.modelData.items || []
            }
            Repeater {
                model: sec.modelData.blocks || []
                delegate: SettingsBlock {
                    required property var modelData
                    width: parent.width
                    page: sec.page
                    title: modelData.title || ""
                    items: modelData.items
                    showIf: modelData.showIf || null
                }
            }
        }
    }

    Loader {
        active: sec.kind === "colors"
        visible: active
        width: parent.width
        sourceComponent: ColorGrid {
            page: sec.page
            section: sec.modelData
        }
    }

    Loader {
        active: sec.kind === "table"
        visible: active
        width: parent.width
        sourceComponent: SizeTable {
            page: sec.page
            section: sec.modelData
        }
    }

    Loader {
        active: sec.kind === "collapsed"
        visible: active
        width: parent.width
        sourceComponent: ThemeGroup {
            page: sec.page
            modelData: sec.modelData
        }
    }
}
