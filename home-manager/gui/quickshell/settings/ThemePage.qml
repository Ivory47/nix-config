import QtQuick
import QtQuick.Controls
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
        restartBar: { title: "Restart status bar", note: "Applies the height and glass changes", label: "Restart", run: () => root.restartBar() }
    })
    property bool restarting: false

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

    // Scrolls the page so that the setting is near the top, and outlines it for a moment.
    function scrollTo(key) {
        const f = fields[key]
        if (!f)
            return
        flick.stopGlide()
        flick.contentY = flick._clamp(f.mapToItem(flick.contentItem, 0, 0).y - 70)
        f.flash()
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
                            width: buttonText.implicitWidth + 24
                            height: 28
                            radius: Theme.radiusSmall
                            color: "transparent"
                            border.width: 1
                            border.color: !root.restarting && buttonArea.containsMouse ? Theme.textMuted : Theme.surfaceAlt
                            opacity: root.restarting ? 0.6 : 1

                            Text {
                                id: buttonText
                                anchors.centerIn: parent
                                text: root.restarting ? "Restarting\u2026" : "\u21BB " + (actionRow.action?.label ?? "")
                                color: Theme.textSecondary
                                font.pixelSize: Theme.textSmall
                            }

                            MouseArea {
                                id: buttonArea
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !root.restarting
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

                Text {
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
