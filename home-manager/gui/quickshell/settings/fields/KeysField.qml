import QtQuick
import QtQuick.Controls
import qs.shared
import qs.controls
import qs.core

// A key binding of the settings app (AppSchema type "keys": AppSettings.keys.<action>, a list of keys).
// The row shows at most two keys and "+N" for the rest, so a long list never widens or clips it. A click
// (or Enter) opens the editor under the row, like a colour's picker (one at a time: AppSettings.openBinding):
// every key with a "×", and a field to add one (Enter adds it and stays in the field; jk / Esc leave). A
// key that another action also has is outlined orange, with a note naming it.
SettingsRow {
    id: root

    readonly property var list: ThemeStore.value(spec.key) || []
    readonly property string action: spec.key.slice("keys.".length)
    readonly property bool open: AppSettings.openBinding === spec.key
    readonly property int shownMax: 2

    // Other actions that have a key of this one: { key: [their labels] }.
    readonly property var clashes: {
        const out = {}
        for (const k of list) {
            const others = map.usedBy(k, action).map(a => labelOf(a))
            if (others.length > 0)
                out[k] = others
        }
        return out
    }
    function labelOf(a) {
        const e = SettingsIndex.entries.find(e => e.spec.key === "keys." + a)
        return e ? e.spec.label : a
    }

    function toggle() {
        AppSettings.openBinding = open ? "" : spec.key
    }
    function add(text) {
        const t = text.trim()
        if (!map.valid(t))
            return false
        const n = map.normal(t)
        if (list.indexOf(n) < 0)
            ThemeStore.set(spec.key, list.concat([n]))
        return true
    }
    function removeAt(i) {
        ThemeStore.set(spec.key, list.filter((_, j) => j !== i))
    }
    // Enter on a key's cap: it goes, the cursor goes to the cap now in its place (or the add field). (The
    // function is made here: the cap's own context is gone once it is removed.)
    function removeAndStay(i) {
        removeAt(i)
        return () => capRepeater.itemAt(Math.min(i, capRepeater.count - 1)) || addBox
    }

    // Keyboard (KeyNav): Enter opens / closes the editor, i opens it in the add field; the keys' caps and
    // the field are stops of their own while it is open. Coming to another binding closes this one.
    function navActivate() { toggle() }
    function navEdit() {
        AppSettings.openBinding = spec.key
        return () => {
            addField.forceActiveFocus()
            return addBox
        }
    }
    function navFocused() {
        if (AppSettings.openBinding !== "" && !open)
            AppSettings.openBinding = ""
    }

    belowHeight: open ? editor.height + Theme.spacingMedium : 0

    KeyMap {
        id: map
    }

    // The closed row: two keys, "+N", an arrow; a click opens the editor.
    Item {
        width: capsRow.width
        height: 44

        Row {
            id: capsRow
            height: 44
            spacing: 6

            Repeater {
                model: root.list.slice(0, root.shownMax)
                delegate: KeyCap {
                    required property string modelData
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData
                    warn: root.clashes[modelData] !== undefined
                }
            }
            KeyCap {
                visible: root.list.length > root.shownMax
                anchors.verticalCenter: parent.verticalCenter
                text: "+" + (root.list.length - root.shownMax)
                muted: true
            }
            Text {
                visible: root.list.length === 0
                anchors.verticalCenter: parent.verticalCenter
                text: "no key"
                color: Theme.textMuted
                font.pixelSize: Theme.textSmall + 1
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                horizontalAlignment: Text.AlignHCenter
                text: root.open ? "▾" : "▸"
                color: Theme.textMuted
                font.pixelSize: Theme.textSmall + 1
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggle()
        }
    }

    // The editor: every key (× removes it), the add field, what clashes.
    below: Column {
        id: editor
        visible: root.open
        x: Theme.spacingMedium
        width: parent.width - 2 * Theme.spacingMedium
        spacing: Theme.spacingSmall

        Flow {
            id: caps
            width: parent.width
            spacing: 6

            Repeater {
                id: capRepeater
                model: root.list
                delegate: KeyCap {
                    id: cap
                    required property string modelData
                    required property int index
                    text: modelData
                    removable: true
                    warn: root.clashes[modelData] !== undefined
                    onRemoved: root.removeAt(index)

                    // A stop: Enter removes this key; the cursor stays on the keys (or goes to the field).
                    readonly property bool navStop: true
                    readonly property var navFrame: ({ x: -3, y: -3, width: width + 6, height: height + 6, radius: Theme.radiusSmall + 2 })
                    function navActivate() { return root.removeAndStay(index) }
                }
            }

            Item {
                id: addBox
                width: 150
                height: 24
                readonly property bool navStop: true
                readonly property var navFrame: ({ x: -3, y: -3, width: width + 6, height: height + 6, radius: Theme.radiusSmall + 2 })
                function navActivate() { addField.forceActiveFocus() }
                function navEdit() { addField.forceActiveFocus() }

                TextField {
                    id: addField
                    anchors.fill: parent
                    leftPadding: 8
                    rightPadding: 8
                    topPadding: 0
                    bottomPadding: 0
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true
                    font.family: "monospace"
                    font.pixelSize: Theme.textSmall + 1
                    color: Theme.text
                    placeholderText: "add a key"
                    placeholderTextColor: Theme.textMuted

                    readonly property bool bad: text.trim().length > 0 && !map.valid(text)

                    background: Rectangle {
                        radius: Theme.radiusSmall
                        color: "transparent"
                        border.width: 1
                        border.color: addField.bad ? Theme.red : addField.activeFocus ? Theme.accent : Theme.surfaceAlt
                    }

                    // Enter adds the key and stays here for the next one (FieldKeys in vim mode, else accepted).
                    function navEnter() {
                        if (root.add(text))
                            text = ""
                    }
                    function navCancel() { text = "" }
                    onAccepted: navEnter()
                    Keys.priority: Keys.BeforeItem
                    Keys.onPressed: event => FieldKeys.press(event, addField)
                }
            }
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.textSmall
            color: addField.bad ? Theme.red : Object.keys(root.clashes).length > 0 ? Theme.orange : Theme.textMuted
            text: addField.bad ? "Not a key: a character, Ctrl+d, Shift+Tab, Enter, Esc, Up, or two characters (gg)"
                : Object.keys(root.clashes).length > 0
                    ? Object.keys(root.clashes).map(k => k + " also: " + root.clashes[k].join(", ")).join(" · ")
                : "Enter adds a key, jk or Esc leaves the field"
        }
    }
}
