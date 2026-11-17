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

    function setOpen(id, on) {
        const next = Object.assign({}, open)
        if (on)
            next[id] = true
        else
            delete next[id]
        open = next
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

    KineticFlickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight + Theme.spacingLarge
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            id: bar
            width: 6
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: 4
                radius: 2
                color: Theme.surfaceAlt
                opacity: bar.active ? 1 : 0.6
            }
            background: Item {}
        }

        Column {
            id: column
            x: 6
            width: flick.width - 16
            spacing: Theme.spacingMedium

            // The section title, as on the Theme page.
            Column {
                width: parent.width

                Text {
                    bottomPadding: 2
                    text: "Window rules"
                    color: Theme.accent
                    font.pixelSize: Theme.textLarge - 2
                    font.bold: true
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.surfaceAlt
                }
            }

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Rules made here are saved to hyprland-settings.lua next to hyprland.lua (not committed to git) "
                    + "and applied to Hyprland at once, without hms. They load after the base config, so a rule for the "
                    + "same windows overrides it. If several rules here match one window, the one higher in the list wins."
                color: Theme.textSecondary
                font.pixelSize: Theme.textSmall
            }

            // Add, reload, and what happened last.
            Row {
                spacing: Theme.spacingMedium

                Rectangle {
                    id: addButton
                    anchors.verticalCenter: parent.verticalCenter
                    width: addText.implicitWidth + 28
                    height: 32
                    radius: Theme.radiusSmall
                    color: addArea.pressed ? Theme.textSecondary : Theme.accent

                    Text {
                        id: addText
                        anchors.centerIn: parent
                        text: "+ Add rule"
                        color: Theme.background
                        font.pixelSize: Theme.textMedium
                        font.bold: true
                    }

                    MouseArea {
                        id: addArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.addRule()
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: reloadText.implicitWidth + 24
                    height: 32
                    radius: Theme.radiusSmall
                    color: "transparent"
                    border.width: 1
                    border.color: reloadArea.containsMouse ? Theme.textMuted : Theme.surfaceAlt

                    Text {
                        id: reloadText
                        anchors.centerIn: parent
                        text: "↻ Reload Hyprland"
                        color: Theme.textSecondary
                        font.pixelSize: Theme.textSmall
                    }

                    MouseArea {
                        id: reloadArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: HyprlandStore.reloadNow()
                    }
                }

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
                        model: HyprlandStore.baseRules

                        delegate: Rectangle {
                            id: baseRule
                            required property var modelData
                            width: parent.width
                            height: 52
                            radius: Theme.radiusMedium
                            color: "transparent"
                            border.width: 1
                            border.color: Theme.surfaceAlt

                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingMedium
                                anchors.right: overrideButton.left
                                anchors.rightMargin: Theme.spacingMedium
                                anchors.verticalCenter: parent.verticalCenter
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
                                    color: Theme.textMuted
                                    font.pixelSize: Theme.textSmall - 1
                                }
                            }

                            Rectangle {
                                id: overrideButton
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingMedium
                                anchors.verticalCenter: parent.verticalCenter
                                width: overrideText.implicitWidth + 24
                                height: 28
                                radius: Theme.radiusSmall
                                color: "transparent"
                                border.width: 1
                                border.color: overrideArea.containsMouse ? Theme.textMuted : Theme.surfaceAlt

                                Text {
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
}
