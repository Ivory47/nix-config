import QtQuick
import QtQuick.Controls
import qs.shared

// The Hyprland category: window rules with the Lucent glass parameters, kept in hyprland-settings.lua
// (see HyprlandStore.qml) so that they never touch the base config, and applied at once. Below the
// rules, the base config's own rules are listed read-only, with a button that starts an override
// from one (a rule of ours comes later in the config, so it wins).
Item {
    id: root

    // Which rule cards are open (id -> true). The page keeps it, the cards only show it.
    property var open: ({})
    property bool baseOpen: false
    // Base rules shown with their details (index -> true).
    property var baseExpanded: ({})

    // A rule written into hyprland.lua by hand shows up when the page is shown again.
    onVisibleChanged: if (visible) HyprlandStore.reloadBase()

    function setOpen(id, on) {
        const next = Object.assign({}, open)
        if (on)
            next[id] = true
        else
            delete next[id]
        open = next
    }

    // Shows what an undo or redo changed (SettingsView.jumpTo): `key` is a rule's id, "<id>#<field>" (a
    // field of its editor, RuleCard.find) or "base:<name>" (a base rule that follows the default look
    // or not). The card is opened first, and the page scrolled once it has its new size.
    function scrollTo(key, gentle) {
        const base = key.startsWith("base:")
        if (base)
            baseOpen = true
        else if (HyprlandStore.byId(key.split("#")[0]))
            setOpen(key.split("#")[0], true)
        else
            return
        scrollTimer.key = key
        scrollTimer.gentle = !!gentle
        scrollTimer.restart()
    }

    function _scrollNow(key, gentle) {
        if (key.startsWith("base:")) {
            const i = HyprlandStore.baseRules.findIndex(b => b.name === key.slice(5))
            const item = i >= 0 ? baseRepeater.itemAt(i) : null
            if (item) {
                flick.show(item, gentle)
                item.flash()
            }
            return
        }
        const parts = key.split("#")
        const card = ruleRepeater.itemAt(HyprlandStore.ruleIds.indexOf(parts[0]))
        if (!card)
            return
        const field = parts[1] ? card.find(parts[1]) : null
        flick.show(field || card, gentle)
        card.flash(parts[1])
    }

    Timer {
        id: scrollTimer
        property string key: ""
        property bool gentle: false
        interval: 60
        onTriggered: root._scrollNow(key, gentle)
    }

    function addRule(base) {
        const id = base === undefined ? HyprlandStore.addRule() : base
        setOpen(id, true)
        flick.stopGlide()
        flick.contentY = 0
    }

    function summaryOfBase(b) {
        const parts = []
        for (const k of Object.keys(b.match))
            parts.push(k.replace("_", " ") + " " + b.match[k])
        return parts.length ? parts.join(" · ") : "all windows"
    }

    PageHeader {
        id: header
        width: parent.width
        title: "Window rules"
        description: "Glass for other programs' windows. Applied to Hyprland at once, without hms"

        ActionButton {
            primary: true
            text: "+ Add rule"
            onClicked: root.addRule()
        }

        ActionButton {
            text: "↻ Reload Hyprland"
            onClicked: HyprlandStore.reloadNow()
        }
    }

    SettingsPage {
        id: flick
        anchors.top: header.bottom
        anchors.topMargin: Theme.spacingMedium
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: Theme.spacingMedium

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Rules made here are saved to hyprland-settings.lua next to hyprland.lua (not committed to git). "
                + "They load after the base config, so a rule for the same windows overrides it. If several rules "
                + "here match one window, the one higher in the list wins. A base rule with glass can follow the default "
                + "look (Theme › Glass) and keep its own blur, corners and opacity: Default look on its row below."
            color: Theme.textSecondary
            font.pixelSize: Theme.textSmall
        }

        // What happened last.
        Row {
            visible: ["saving", "reloading", "ok", "error"].includes(HyprlandStore.status)
            spacing: Theme.spacingMedium

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: HyprlandStore.status === "saving" || HyprlandStore.status === "reloading" ? "Applying…"
                    : HyprlandStore.status === "ok" ? "✓ Applied to Hyprland"
                    : HyprlandStore.status === "error" ? "⚠ Hyprland reports a problem"
                    : ""
                color: HyprlandStore.status === "ok" ? Theme.green
                    : HyprlandStore.status === "error" ? Theme.orange : Theme.textSecondary
                font.pixelSize: Theme.textSmall
            }
        }

        Text {
            visible: HyprlandStore.status === "error" && HyprlandStore.message.length > 0
            width: parent.width
            wrapMode: Text.WordWrap
            text: HyprlandStore.message
            color: Theme.orange
            font.family: "monospace"
            font.pixelSize: Theme.textSmall - 1
        }

        Repeater {
            id: ruleRepeater
            model: HyprlandStore.ruleIds

            delegate: RuleCard {
                required property string modelData
                ruleId: modelData
                expanded: !!root.open[modelData]
                onToggled: open => root.setOpen(modelData, open)
            }
        }

        Text {
            visible: HyprlandStore.ruleIds.length === 0
            width: parent.width
            wrapMode: Text.WordWrap
            text: "No rules yet. Add one to give a program's windows glass (or to switch the glass of a base rule off)."
            color: Theme.textMuted
            font.pixelSize: Theme.textMedium
        }

        // ---- the base config's rules ----
        Column {
            width: parent.width
            topPadding: Theme.spacingMedium

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.surfaceAlt
            }

            Item {
                id: baseHeader
                width: parent.width
                height: 42

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 1
                    radius: Theme.radiusSmall
                    color: baseArea.containsMouse ? Theme.surface : "transparent"
                }

                Text {
                    id: baseChevron
                    x: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    text: root.baseOpen ? "▾" : "▸"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.textMedium
                }

                Column {
                    anchors.left: baseChevron.right
                    anchors.leftMargin: Theme.spacingSmall
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        text: "Base config rules (" + HyprlandStore.baseRules.length + ")"
                        color: Theme.text
                        font.pixelSize: Theme.textMedium
                        font.bold: true
                    }
                    Text {
                        text: "From hyprland.lua, read-only. Override starts a rule of yours from one"
                        color: Theme.textMuted
                        font.pixelSize: Theme.textSmall - 1
                    }
                }

                MouseArea {
                    id: baseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.baseOpen = !root.baseOpen
                }
            }

            Column {
                visible: root.baseOpen
                width: parent.width
                spacing: Theme.spacingSmall

                Repeater {
                    id: baseRepeater
                    model: HyprlandStore.baseRules

                    delegate: Rectangle {
                        id: baseRule
                        required property var modelData
                        required property int index
                        readonly property bool expanded: !!root.baseExpanded[index]
                        readonly property var glass: modelData.glass
                        width: parent.width
                        height: 52 + (expanded ? details.height + Theme.spacingMedium : 0)
                        radius: Theme.radiusMedium
                        color: "transparent"
                        border.width: 1
                        border.color: expanded ? Theme.textMuted : Theme.surfaceAlt

                        function flash() { baseFrame.flash() }
                        FlashFrame { id: baseFrame }

                        // The row: click to show the details (the buttons on it take their own clicks).
                        Item {
                            id: head
                            width: parent.width
                            height: 52

                            Text {
                                x: Theme.spacingMedium
                                anchors.verticalCenter: parent.verticalCenter
                                text: baseRule.expanded ? "\u25BE" : "\u25B8"
                                color: Theme.textSecondary
                                font.pixelSize: Theme.textMedium
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const next = Object.assign({}, root.baseExpanded)
                                    if (baseRule.expanded)
                                        delete next[baseRule.index]
                                    else
                                        next[baseRule.index] = true
                                    root.baseExpanded = next
                                }
                            }
                        }

                        // The details: its other effects, and its glass with every parameter (the ones it
                        // leaves out at the plugin's default, dimmed; with the default look followed, the
                        // look's values).
                        Column {
                            id: details
                            visible: baseRule.expanded
                            x: Theme.spacingMedium
                            y: 52
                            width: parent.width - 2 * Theme.spacingMedium
                            spacing: 2

                            Repeater {
                                model: baseRule.modelData.effects.filter(e => e.key !== "lucent_glass")

                                delegate: Text {
                                    required property var modelData
                                    width: details.width
                                    elide: Text.ElideRight
                                    text: modelData.key + " = " + modelData.value
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.textSmall
                                    font.family: "monospace"
                                }
                            }

                            Text {
                                visible: !baseRule.glass || baseRule.glass.mode === "off"
                                text: !baseRule.glass ? "No glass in this rule" : "Glass off for these windows"
                                color: Theme.textMuted
                                font.pixelSize: Theme.textSmall
                            }

                            Loader {
                                active: baseRule.expanded && !!baseRule.glass && baseRule.glass.mode === "custom"
                                visible: active
                                width: parent.width
                                sourceComponent: GlassParamBlocks {
                                    readOnly: true
                                    values: HyprlandStore.effectiveParams(baseRule.glass.params, followButton.on)
                                }
                            }
                        }

                        Column {
                            anchors.left: parent.left
                            // (Clear of the chevron.)
                            anchors.leftMargin: Theme.spacingMedium + 20
                            anchors.right: followButton.visible ? followButton.left : overrideButton.left
                            anchors.rightMargin: Theme.spacingMedium
                            anchors.verticalCenter: head.verticalCenter
                            spacing: 2

                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: baseRule.modelData.name || root.summaryOfBase(baseRule.modelData)
                                color: Theme.text
                                font.pixelSize: Theme.textMedium
                            }
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: (baseRule.modelData.name ? root.summaryOfBase(baseRule.modelData) + "  ·  " : "")
                                    + baseRule.modelData.effects.map(e => e.key).join(", ")
                                    + (followButton.on ? "  ·  follows the default look" : "")
                                color: Theme.textMuted
                                font.pixelSize: Theme.textSmall - 1
                            }
                        }

                        // A base rule with glass can follow the default look (HyprlandStore.follow).
                        ActionButton {
                            id: followButton
                            readonly property bool on: HyprlandStore.follows(baseRule.modelData.name)
                            visible: !!baseRule.modelData.name && !!baseRule.modelData.glass && baseRule.modelData.glass.mode === "custom"
                            anchors.right: overrideButton.left
                            anchors.rightMargin: Theme.spacingSmall
                            anchors.verticalCenter: head.verticalCenter
                            height: 28
                            primary: on
                            text: on ? "✓ Default look" : "Default look"
                            onClicked: HyprlandStore.setFollow(baseRule.modelData.name, !on)
                        }

                        Rectangle {
                            id: overrideButton
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingMedium
                            anchors.verticalCenter: head.verticalCenter
                            width: overrideText.implicitWidth + 24
                            height: 28
                            radius: Theme.radiusSmall
                            color: "transparent"
                            border.width: 1
                            border.color: overrideArea.containsMouse ? Theme.textMuted : Theme.surfaceAlt

                            CenteredText {
                                id: overrideText
                                anchors.centerIn: parent
                                text: "Override"
                                color: Theme.textSecondary
                                font.pixelSize: Theme.textSmall
                            }

                            MouseArea {
                                id: overrideArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.addRule(HyprlandStore.overrideOf(baseRule.modelData))
                            }
                        }
                    }
                }

                Text {
                    visible: HyprlandStore.baseRules.length === 0
                    text: "No window rules found in hyprland.lua."
                    color: Theme.textMuted
                    font.pixelSize: Theme.textSmall
                }
            }
        }

        Item { width: 1; height: Theme.spacingLarge }
    }
}
