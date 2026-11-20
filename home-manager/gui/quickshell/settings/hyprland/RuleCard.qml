import QtQuick
import qs.shared
import qs.controls

// One window rule of the Hyprland page: a header row (enable switch, what it matches, what it does,
// duplicate and delete) that opens into the editor: name, what to match, and the glass (inherit /
// custom / off, and the parameters). All changes go to HyprlandStore, which writes
// hyprland-settings.lua and reloads Hyprland. Nothing translucent: it sits over the glass.
Rectangle {
    id: root

    required property string ruleId
    property bool expanded: false

    readonly property var rule: HyprlandStore.byId(ruleId)
    readonly property var problems: rule ? HyprlandStore.problems(rule) : []
    // A problem that stops the rule from being written (the third, "no effect", is only a hint).
    readonly property bool broken: rule ? !HyprlandStore.writable(rule) : false

    signal toggled(bool open)

    // dd on the keyboard (KeyNav): "Delete this rule? y / n" over the header, then navDelete.
    property bool confirming: false
    function navDelete() {
        HyprlandStore.remove(ruleId)
    }

    // The row of a field (a TextRow, a glass parameter's SettingField: their `fieldId`) in the editor, or null.
    function find(field, from) {
        for (const c of (from || content).children) {
            if (c.fieldId === field)
                return c
            const r = find(field, c)
            if (r)
                return r
        }
        return null
    }

    // Outlines the card (or one field of it) for a moment.
    function flash(field) {
        const f = field ? find(field) : null
        if (f)
            f.flash()
        else
            frame.flash()
    }

    FlashFrame { id: frame }

    visible: !!rule
    width: parent ? parent.width : 0
    height: visible ? content.height : 0
    radius: Theme.radiusMedium
    color: "transparent"
    border.width: 1
    border.color: expanded ? Theme.textMuted : Theme.surfaceAlt

    function glassSummary() {
        if (!rule)
            return ""
        const g = rule.glass
        if (g.mode === "off")
            return "glass off"
        const ne = (rule.effects || []).length
        if (g.mode === "inherit")
            return ne > 0 ? ne + (ne === 1 ? " effect" : " effects") : "no effect yet"
        if (g.mode === "default")
            return "glass: default look"
        const n = Object.keys(g.params).length
        return n === 0 ? "glass: plain blur" : "glass: " + n + (n === 1 ? " parameter" : " parameters")
    }

    Column {
        id: content
        width: parent.width

        // ---- header ----
        Item {
            id: header
            width: parent.width
            height: 56

            // Keyboard (KeyNav): Enter opens / closes the editor, l opens, h closes.
            readonly property bool navStop: true
            function navActivate() { root.toggled(!root.expanded) }
            function navAdjust(dir) { root.toggled(dir > 0) }

            MouseArea {
                id: headerArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggled(!root.expanded)
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: Theme.radiusMedium
                // (Opaque: nothing translucent over the glass.)
                color: headerArea.containsMouse ? Theme.surface : "transparent"
            }

            Chevron {
                id: chevron
                x: 11
                anchors.verticalCenter: parent.verticalCenter
                open: root.expanded
            }

            // Enable switch.
            Toggle {
                id: sw
                anchors.left: chevron.right
                anchors.leftMargin: Theme.spacingSmall
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                height: 20
                checked: !!root.rule && root.rule.enabled
                onToggled: HyprlandStore.setEnabled(root.ruleId, !root.rule.enabled)

                // l: on, h: off, Enter: the other.
                readonly property bool navStop: true
                function navActivate() { HyprlandStore.setEnabled(root.ruleId, !root.rule.enabled) }
                function navAdjust(dir) {
                    if ((dir > 0) !== root.rule.enabled)
                        HyprlandStore.setEnabled(root.ruleId, dir > 0)
                }
            }

            Column {
                anchors.left: sw.right
                anchors.leftMargin: Theme.spacingMedium
                anchors.right: buttons.left
                anchors.rightMargin: Theme.spacingMedium
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.rule ? (root.rule.name || HyprlandStore.matchSummary(root.rule)) : ""
                    color: root.rule && root.rule.enabled ? Theme.text : Theme.textMuted
                    font.pixelSize: Theme.textMedium
                    font.bold: true
                }

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.rule
                        ? (root.rule.name ? HyprlandStore.matchSummary(root.rule) + "  ·  " : "") + root.glassSummary()
                          + (root.rule.enabled ? "" : "  ·  off")
                        : ""
                    color: root.problems.length > 0 && root.broken ? Theme.orange : Theme.textMuted
                    font.pixelSize: Theme.textSmall - 1
                }
            }

            Row {
                id: buttons
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingMedium
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingSmall

                Repeater {
                    model: [ { glyph: "⧉", tip: "dup" }, { glyph: "×", tip: "del" } ]

                    delegate: Rectangle {
                        id: btn
                        required property var modelData
                        width: 28
                        height: 28
                        radius: Theme.radiusSmall
                        color: "transparent"
                        border.width: 1
                        border.color: btnArea.containsMouse ? (modelData.tip === "del" ? Theme.red : Theme.textMuted) : Theme.surfaceAlt

                        // Enter: duplicate, or (delete) ask first, like dd.
                        readonly property bool navStop: true
                        function navActivate() {
                            if (modelData.tip === "del")
                                return "delete"
                            HyprlandStore.duplicate(root.ruleId)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: btn.modelData.glyph
                            color: btnArea.containsMouse && btn.modelData.tip === "del" ? Theme.red : Theme.textSecondary
                            font.pixelSize: Theme.textMedium
                        }

                        MouseArea {
                            id: btnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (btn.modelData.tip === "del")
                                    HyprlandStore.remove(root.ruleId)
                                else
                                    HyprlandStore.duplicate(root.ruleId)
                            }
                        }
                    }
                }
            }

            // dd (KeyNav): asks before deleting; y deletes, any other key keeps the rule.
            Rectangle {
                visible: root.confirming
                z: 1
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingMedium
                anchors.verticalCenter: parent.verticalCenter
                width: confirmText.implicitWidth + 24
                height: 32
                radius: Theme.radiusSmall
                color: Theme.background
                border.width: 1
                border.color: Theme.red

                CenteredText {
                    id: confirmText
                    anchors.centerIn: parent
                    text: "Delete this rule?   y / n"
                    color: Theme.red
                    font.pixelSize: Theme.textSmall
                    font.bold: true
                }
            }
        }

        // ---- editor ----
        Column {
            visible: root.expanded
            x: Theme.spacingMedium
            width: parent.width - 2 * Theme.spacingMedium
            spacing: 0
            bottomPadding: Theme.spacingMedium

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.surfaceAlt
            }

            Text {
                visible: root.problems.length > 0
                width: parent.width
                topPadding: Theme.spacingSmall
                bottomPadding: Theme.spacingSmall
                wrapMode: Text.WordWrap
                text: "⚠ " + root.problems.join(".  ")
                color: root.broken ? Theme.orange : Theme.textMuted
                font.pixelSize: Theme.textSmall
            }

            TextRow {
                fieldId: "name"
                label: "Name"
                note: "Optional, for your own reference"
                placeholder: "e.g. Terminal glass"
                value: root.rule ? root.rule.name : ""
                onEdited: text => HyprlandStore.setName(root.ruleId, text)
            }

            Text {
                topPadding: Theme.spacingSmall
                bottomPadding: 2
                text: "MATCH   ·   regular expressions; leave a field empty to ignore it"
                color: Theme.textMuted
                font.pixelSize: Theme.textSmall - 1
                font.bold: true
                font.letterSpacing: 1.0
            }

            Repeater {
                model: [
                    { key: "class", label: "Class", note: "hyprctl clients: class", ph: "^kitty$" },
                    { key: "title", label: "Title", note: "The window title", ph: "" },
                    { key: "initial_class", label: "Initial class", note: "The class when it opened", ph: "" },
                    { key: "initial_title", label: "Initial title", note: "The title when it opened", ph: "" }
                ]

                delegate: TextRow {
                    required property var modelData
                    fieldId: "match." + modelData.key
                    label: modelData.label
                    note: modelData.note
                    placeholder: modelData.ph
                    value: root.rule ? root.rule.match[modelData.key] : ""
                    valid: root.rule ? HyprlandStore.validRegex(root.rule.match[modelData.key]) : true
                    onEdited: text => HyprlandStore.setMatch(root.ruleId, modelData.key, text)
                }
            }

            Item {
                width: parent.width
                height: 44

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Floating"
                    color: Theme.text
                    font.pixelSize: Theme.textMedium
                }

                Segmented {
                    navStop: true
                    anchors.left: parent.left
                    anchors.leftMargin: 200
                    anchors.verticalCenter: parent.verticalCenter
                    options: [ { id: "", label: "Either" }, { id: "yes", label: "Floating" }, { id: "no", label: "Tiled" } ]
                    current: root.rule ? root.rule.match.float : ""
                    onPicked: id => HyprlandStore.setMatch(root.ruleId, "float", id)
                }
            }

            Text {
                visible: !!root.rule && root.rule.effects.length > 0
                topPadding: Theme.spacingMedium
                bottomPadding: Theme.spacingSmall
                text: "EFFECTS   ·   other window rule effects (Lua values)"
                color: Theme.textMuted
                font.pixelSize: Theme.textSmall - 1
                font.bold: true
                font.letterSpacing: 1.0
            }

            Repeater {
                // A count, not the list: an edit replaces the list, and the rows (with the focus) must stay.
                model: root.rule ? root.rule.effects.length : 0

                delegate: TextRow {
                    required property int index
                    fieldId: "effect." + index
                    label: root.rule.effects[index].key
                    value: root.rule.effects[index].value
                    onEdited: text => HyprlandStore.setEffect(root.ruleId, index, text)
                }
            }

            Text {
                topPadding: Theme.spacingMedium
                bottomPadding: Theme.spacingSmall
                text: "GLASS   ·   drawn by the Lucent plugin behind the window"
                color: Theme.textMuted
                font.pixelSize: Theme.textSmall - 1
                font.bold: true
                font.letterSpacing: 1.0
            }

            Segmented {
                navStop: true
                options: [
                    { id: "inherit", label: "No change" },
                    { id: "default", label: "Default look" },
                    { id: "custom", label: "Glass" },
                    { id: "off", label: "Glass off" }
                ]
                current: root.rule ? root.rule.glass.mode : "inherit"
                onPicked: id => HyprlandStore.setMode(root.ruleId, id)
            }

            Text {
                width: parent.width
                topPadding: Theme.spacingSmall
                wrapMode: Text.WordWrap
                text: !root.rule ? ""
                    : root.rule.glass.mode === "inherit" ? (root.rule.effects.length > 0 ? "This rule leaves the glass as it is. Pick Glass to add glass, or Glass off to switch it off." : "This rule does nothing yet. Pick Glass to add glass, or Glass off to switch the glass of a matching base rule off.")
                    : root.rule.glass.mode === "off" ? "Matching windows get no glass, even if a rule in the base config gives them some (this rule comes later, so it wins)."
                    : root.rule.glass.mode === "default" ? "The look set on the Theme › Glass page, kept up to date when it changes. Blur, corners and opacity below are this rule's own."
                    : "Only the parameters you change are set (marked with ↺); the rest keep the plugin's defaults, shown dimmed. It shows where the window itself is translucent."
                color: Theme.textMuted
                font.pixelSize: Theme.textSmall - 1
            }

            Item { width: 1; height: Theme.spacingSmall }

            // The parameters, grouped (Blur, Tone, Rim, Light, Window); with the default look only the
            // rule's own keys (the look comes from Theme › Glass).
            GlassParamBlocks {
                visible: !!root.rule && (root.rule.glass.mode === "custom" || root.rule.glass.mode === "default")
                width: parent.width
                ruleId: root.ruleId
                keys: root.rule && root.rule.glass.mode === "default" ? HyprlandStore.ownKeys : null
            }

            Rectangle {
                visible: root.rule && root.rule.glass.mode === "custom" && Object.keys(root.rule.glass.params).length > 0
                width: resetText.implicitWidth + 24
                height: 28
                radius: Theme.radiusSmall
                color: "transparent"
                border.width: 1
                border.color: resetArea.containsMouse ? Theme.textMuted : Theme.surfaceAlt

                readonly property bool navStop: true
                function navActivate() { HyprlandStore.clearParams(root.ruleId) }

                CenteredText {
                    id: resetText
                    anchors.centerIn: parent
                    text: "Reset all parameters"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.textSmall
                }

                MouseArea {
                    id: resetArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: HyprlandStore.clearParams(root.ruleId)
                }
            }
        }
    }
}
