import QtQuick
import QtQuick.Controls
import qs.shared
import qs.controls

// The Hyprland category: window rules with the Lucent glass parameters, kept in hyprland-settings.lua
// (see HyprlandStore.qml) so that they never touch the base config, and applied at once. Below the
// rules, the base config's own rules are listed read-only, with a button that starts an override
// from one (a rule of ours comes later in the config, so it wins).
Item {
    id: root

    // Which rule cards are open (id -> true). The page keeps it, the cards only show it.
    property var open: ({})

    // A rule written into hyprland.lua by hand shows up when the page is shown again.
    onVisibleChanged: if (visible) BaseRules.reload()

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
            baseList.open = true
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
            const item = baseList.itemFor(key)
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

    // For the keyboard (KeyNav): the item a key of scrollTo is about (after an undo or redo).
    function navItemFor(key) {
        if (key.startsWith("base:")) {
            return baseList.itemFor(key)
        }
        const parts = key.split("#")
        const card = ruleRepeater.itemAt(HyprlandStore.ruleIds.indexOf(parts[0]))
        return card ? (parts[1] ? card.find(parts[1]) : null) || card : null
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
        BaseRuleList {
            id: baseList
            width: parent.width
            onOverrideRequested: rule => root.addRule(HyprlandStore.overrideOf(rule))
        }

        Item { width: 1; height: Theme.spacingLarge }
    }
}
