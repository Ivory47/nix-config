import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell.Io
import qs.shared

// Every value of Theme.qml, in groups. Changing one writes it to the settings app's file (see
// ThemeStore) and every shell follows. The reset arrow next to a value brings back the default
// from ThemeDefaults.qml.
Item {
    id: root

    readonly property var sections: ThemeSchema.sections

    // The actions of the section buttons (ThemeSchema: `button`): id -> { label, run() }.
    readonly property var actions: ({
        restartBar: { title: "Restart status bar", note: "Applies the height and glass changes", label: "Restart", glyph: "\u21BB ", busy: root.restarting, busyText: "Restarting\u2026", run: () => root.restartBar() },
        testNotification: { title: "Test notification", note: "Shows a notification with the settings above", label: "Send", icon: "play", busy: root.testSent, busyText: "Sent", run: () => root.sendTest() }
    })
    property bool restarting: false
    property bool testSent: false

    // Sends a notification over D-Bus (to whatever notification server is running: ours).
    function sendTest() {
        if (testSent)
            return
        testSent = true
        testTimer.restart()
        testProc.running = true
    }

    Process {
        id: testProc
        // ("--" so that the timeout -1 is not taken for an option)
        command: ["busctl", "--user", "call", "--", "org.freedesktop.Notifications", "/org/freedesktop/Notifications",
            "org.freedesktop.Notifications", "Notify", "susssasa{sv}i", "Settings", "0", "preferences-system",
            "Test notification", "This is how a notification looks with your settings.", "0", "0", "-1"]
    }

    Timer {
        id: testTimer
        interval: 1500
        onTriggered: root.testSent = false
    }

    // Restarts the status bar (some values only apply when it starts). Its process is found by
    // the layer it owns (`pkill -f` would also match this command) and started again detached,
    // so that it outlives this one. If the bar is not running, this just starts it.
    function restartBar() {
        if (restarting)
            return
        restarting = true
        restartTimer.restart()
        restartProc.running = true
    }

    Process {
        id: restartProc
        command: ["sh", "-c",
            "kill $(hyprctl layers | grep 'namespace: statusbar' | sed 's/.*pid: //' | sort -u) 2>/dev/null;"
            + " sleep 0.6; setsid -f qs -c status-bar >/dev/null 2>&1"]
    }

    Timer {
        id: restartTimer
        interval: 3000
        onTriggered: root.restarting = false
    }

    // key -> the field of that setting, to scroll to it.
    property var fields: ({})

    // The collapsible groups (ThemeSchema `groups`): which are open (id -> true), and which group a
    // setting is in (key -> id). All start closed.
    property var openGroups: ({})
    readonly property var groupOf: {
        const out = {}
        for (const s of sections)
            for (const g of (s.groups || []))
                for (const item of g.items)
                    out[item.key] = g.id
        return out
    }

    function setGroupOpen(id, open) {
        const next = Object.assign({}, openGroups)
        if (open)
            next[id] = true
        else
            delete next[id]
        openGroups = next
    }

    // How many of the settings of a group were changed from their defaults (shown on a closed group,
    // so that a change cannot hide in it).
    function changedIn(items) {
        let n = 0
        for (const item of items)
            if (ThemeStore.isSet(item.key))
                n++
        return n
    }

    // Scrolls the page so that the setting is near the top, and outlines it for a moment. A setting in
    // a closed group opens the group first (and waits for the page to be laid out again).
    function scrollTo(key) {
        const g = groupOf[key]
        if (g && !openGroups[g]) {
            setGroupOpen(g, true)
            scrollTimer.key = key
            scrollTimer.restart()
            return
        }
        _scrollNow(key)
    }

    function _scrollNow(key) {
        const f = fields[key]
        if (!f)
            return
        flick.stopGlide()
        flick.contentY = flick._clamp(f.mapToItem(flick.contentItem, 0, 0).y - 70)
        f.flash()
    }

    Timer {
        id: scrollTimer
        property string key: ""
        interval: 60
        onTriggered: root._scrollNow(key)
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
            x: 6 // room for the outline of a row (a row is outlined 4 px outside its edges)
            width: flick.width - 16
            spacing: 0

            Repeater {
                model: root.sections

                delegate: Column {
                    id: section
                    required property var modelData
                    required property int index
                    width: column.width

                    // The section title.
                    Item {
                        width: parent.width
                        height: sectionTitle.implicitHeight

                        Text {
                            id: sectionTitle
                            topPadding: section.index === 0 ? 0 : Theme.spacingLarge
                            bottomPadding: 2
                            text: section.modelData.title
                            color: Theme.accent
                            font.pixelSize: Theme.textLarge - 2
                            font.bold: true
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.surfaceAlt
                    }

                    Repeater {
                        model: section.modelData.items

                        delegate: SettingField {
                            id: field
                            required property var modelData
                            width: section.width
                            spec: modelData

                            Component.onCompleted: root.fields[modelData.key] = field
                        }
                    }

                    // The section's collapsible groups: a header row (click to open or close; closed
                    // shows how many of its settings were changed), then its settings.
                    Repeater {
                        model: section.modelData.groups || []

                        delegate: Column {
                            id: group
                            required property var modelData
                            readonly property bool open: !!root.openGroups[modelData.id]
                            readonly property int changed: root.changedIn(modelData.items)
                            width: section.width

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: Theme.surfaceAlt
                            }

                            Item {
                                id: header
                                width: parent.width
                                height: 42

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.topMargin: 1
                                    radius: Theme.radiusSmall
                                    // (Opaque: nothing translucent over the glass.)
                                    color: headerArea.containsMouse ? Theme.surface : "transparent"
                                }

                                Text {
                                    id: chevron
                                    x: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 16
                                    horizontalAlignment: Text.AlignHCenter
                                    text: group.open ? "\u25BE" : "\u25B8"
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.textMedium
                                }

                                Column {
                                    anchors.left: chevron.right
                                    anchors.leftMargin: Theme.spacingSmall
                                    anchors.right: badge.visible ? badge.left : parent.right
                                    anchors.rightMargin: Theme.spacingMedium
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    Text {
                                        width: parent.width
                                        elide: Text.ElideRight
                                        text: group.modelData.title
                                        color: Theme.text
                                        font.pixelSize: Theme.textMedium
                                        font.bold: true
                                    }
                                    Text {
                                        width: parent.width
                                        elide: Text.ElideRight
                                        text: group.modelData.note || ""
                                        color: Theme.textMuted
                                        font.pixelSize: Theme.textSmall - 1
                                    }
                                }

                                // Closed: how many settings in it were changed.
                                Rectangle {
                                    id: badge
                                    visible: !group.open && group.changed > 0
                                    anchors.right: parent.right
                                    anchors.rightMargin: 22 + Theme.spacingSmall
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: badgeText.implicitWidth + 16
                                    height: 20
                                    radius: 10
                                    color: Theme.accent

                                    CenteredText {
                                        id: badgeText
                                        anchors.centerIn: parent
                                        text: group.changed + " changed"
                                        color: Theme.background
                                        font.pixelSize: Theme.textSmall - 2
                                        font.bold: true
                                    }
                                }

                                MouseArea {
                                    id: headerArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setGroupOpen(group.modelData.id, !group.open)
                                }
                            }

                            // The settings, only while open (an invisible Item takes no room), with a
                            // line on the left: click it to close the group again.
                            Item {
                                visible: group.open
                                width: parent.width
                                height: group.open ? groupBody.height : 0

                                MouseArea {
                                    id: collapseLine
                                    // Centred under the chevron (x 6, width 16: centre 14).
                                    x: 14 - width / 2
                                    width: 12
                                    height: parent.height
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setGroupOpen(group.modelData.id, false)

                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: collapseLine.containsMouse ? 3 : 2
                                        height: parent.height
                                        radius: 1
                                        color: collapseLine.containsMouse ? Theme.accent : Theme.surfaceAlt
                                    }
                                }

                                Column {
                                id: groupBody
                                // Clear of the collapse line (centre 14).
                                readonly property int indent: 16 + Theme.spacingMedium
                                x: groupBody.indent
                                width: parent.width - indent

                                Repeater {
                                    model: group.modelData.items

                                    delegate: Column {
                                        id: groupItem
                                        required property var modelData
                                        width: group.width - groupBody.indent

                                        // A gap between clusters of settings (schema `gapBefore`).
                                        Item { width: 1; height: groupItem.modelData.gapBefore ? Theme.spacingLarge : 0 }

                                        SettingField {
                                            id: groupField
                                            width: parent.width
                                            spec: groupItem.modelData

                                            Component.onCompleted: root.fields[groupItem.modelData.key] = groupField
                                        }
                                    }
                                }
                                }
                            }
                        }
                    }

                    // The section's action (ThemeSchema `button`) as a row of its own, like a
                    // setting: label and note on the left, the button where the controls are.
                    Item {
                        id: actionRow
                        readonly property var action: root.actions[section.modelData.button]
                        visible: !!action
                        width: parent.width
                        height: visible ? 44 : 0

                        Column {
                            anchors.left: parent.left
                            anchors.right: actionButton.left
                            anchors.rightMargin: Theme.spacingMedium
                            y: 22 - height / 2
                            spacing: 1

                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: actionRow.action?.title ?? ""
                                color: Theme.text
                                font.pixelSize: Theme.textMedium
                            }
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: actionRow.action?.note ?? ""
                                color: Theme.textMuted
                                font.pixelSize: Theme.textSmall - 1
                            }
                        }

                        // Right edge where the controls end (the reset arrow's column is to the right).
                        Rectangle {
                            id: actionButton
                            anchors.right: parent.right
                            anchors.rightMargin: 22 + Theme.spacingSmall
                            anchors.verticalCenter: parent.verticalCenter
                            width: buttonRow.width + 24
                            height: 28
                            radius: Theme.radiusSmall
                            color: "transparent"
                            border.width: 1
                            border.color: !actionRow.action?.busy && buttonArea.containsMouse ? Theme.textMuted : Theme.surfaceAlt
                            opacity: actionRow.action?.busy ? 0.6 : 1

                            Row {
                                id: buttonRow
                                anchors.centerIn: parent
                                spacing: 6

                                // A drawn triangle: the font's one sits low (its box is the line's, not the
                                // letters'), this one is centred on the middle of the capital letters.
                                Shape {
                                    visible: actionRow.action?.icon === "play" && !actionRow.action?.busy
                                    width: 7
                                    height: 9
                                    anchors.verticalCenter: parent.verticalCenter
                                    // The letters' ink centre is ~0.5 px below the box centre, and the optical centre
                                    // of "Send" (x-height) lower still: centred on the box it read as too high.
                                    anchors.verticalCenterOffset: 0.75
                                    ShapePath {
                                        fillColor: Theme.textSecondary
                                        strokeWidth: -1
                                        startX: 0
                                        startY: 0
                                        PathLine { x: 7; y: 4.5 }
                                        PathLine { x: 0; y: 9 }
                                    }
                                }

                                CenteredText {
                                    id: buttonText
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: actionRow.action?.busy ? (actionRow.action?.busyText ?? "") : (actionRow.action?.glyph ?? "") + (actionRow.action?.label ?? "")
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.textSmall
                                }
                            }

                            MouseArea {
                                id: buttonArea
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !actionRow.action?.busy
                                cursorShape: Qt.PointingHandCursor
                                onClicked: actionRow.action.run()
                            }
                        }
                    }
                }
            }

            Item { width: 1; height: Theme.spacingLarge }

            Rectangle {
                id: resetAll
                width: 150
                height: 32
                radius: Theme.radiusSmall
                color: "transparent"
                border.width: 1
                border.color: resetAllArea.containsMouse ? Theme.red : Theme.surfaceAlt
                opacity: Object.keys(ThemeStore.values).length > 0 ? 1 : 0.4

                CenteredText {
                    anchors.centerIn: parent
                    text: "Reset all to defaults"
                    color: Theme.text
                    font.pixelSize: Theme.textSmall
                }

                MouseArea {
                    id: resetAllArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ThemeStore.resetAll()
                }
            }
        }
    }
}
