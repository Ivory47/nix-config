import QtQuick
import qs.shared
import qs.controls

// The base config's rules on the Window rules page, read-only (BaseRules): a collapsible list, each rule
// opening to its other effects and its glass parameters, with "Default look" (follow the default look) and
// "Override" (start a rule of the user's from it). The page owns what to do on `overrideRequested`.
Column {
    id: root

    // Open (the list shows), and which base rules show their details (index -> true).
    property bool open: false
    property var expandedRules: ({})
    // "Override" was pressed on a rule: [the base rule]. The page starts a rule of the user's from it.
    signal overrideRequested(var rule)

    topPadding: Theme.spacingMedium

    // One line about what a base rule matches.
    function summaryOf(b) {
        const parts = []
        for (const k of Object.keys(b.match))
            parts.push(k.replace("_", " ") + " " + b.match[k])
        return parts.length ? parts.join(" · ") : "all windows"
    }

    // The row of the base rule that a scrollTo key ("base:<name>") is about, or null.
    function itemFor(key) {
        const i = BaseRules.rules.findIndex(b => b.name === key.slice(5))
        return i >= 0 ? baseRepeater.itemAt(i) : null
    }

    Collapsible {
        width: parent.width
        line: false
        open: root.open
        title: "Base config rules (" + BaseRules.rules.length + ")"
        note: "From hyprland.lua, read-only. Override starts a rule of yours from one"
        onToggled: open => root.open = open

        Column {
            width: parent.width
            spacing: Theme.spacingSmall

            Repeater {
                id: baseRepeater
                model: BaseRules.rules

                delegate: Rectangle {
                    id: baseRule
                    required property var modelData
                    required property int index
                    readonly property bool expanded: !!root.expandedRules[index]
                    readonly property var glass: modelData.glass
                    width: parent.width
                    height: 52 + (expanded ? details.height + Theme.spacingMedium : 0)
                    radius: Theme.radiusMedium
                    color: "transparent"
                    border.width: 1
                    border.color: expanded ? Theme.textMuted : Theme.surfaceAlt

                    function flash() { baseFrame.flash() }
                    FlashFrame { id: baseFrame }

                    function setExpanded(on) {
                        const next = Object.assign({}, root.expandedRules)
                        if (on)
                            next[index] = true
                        else
                            delete next[index]
                        root.expandedRules = next
                    }

                    // The row: click to show the details (the buttons on it take their own clicks).
                    Item {
                        id: head
                        width: parent.width
                        height: 52

                        // Keyboard (KeyNav): Enter shows / hides the details, l shows, h hides.
                        readonly property bool navStop: true
                        function navActivate() { baseRule.setExpanded(!baseRule.expanded) }
                        function navAdjust(dir) { baseRule.setExpanded(dir > 0) }

                        Chevron {
                            x: Theme.spacingMedium
                            anchors.verticalCenter: parent.verticalCenter
                            open: baseRule.expanded
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: baseRule.setExpanded(!baseRule.expanded)
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
                            text: baseRule.modelData.name || root.summaryOf(baseRule.modelData)
                            color: Theme.text
                            font.pixelSize: Theme.textMedium
                        }
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: (baseRule.modelData.name ? root.summaryOf(baseRule.modelData) + "  ·  " : "")
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

                        readonly property bool navStop: true
                        function navActivate() { root.overrideRequested(baseRule.modelData) }

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
                            onClicked: root.overrideRequested(baseRule.modelData)
                        }
                    }
                }
            }

            Text {
                visible: BaseRules.rules.length === 0
                text: "No window rules found in hyprland.lua."
                color: Theme.textMuted
                font.pixelSize: Theme.textSmall
            }
        }
    }
}
