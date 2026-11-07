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
        restartBar: { label: "Restart bar", run: () => root.restartBar() }
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
            x: 0
            width: flick.width - 16
            spacing: 0

            Repeater {
                model: root.sections

                delegate: Column {
                    id: section
                    required property var modelData
                    required property int index
                    width: column.width

                    // The title, and the section's button at the right end if it has one.
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

                        Rectangle {
                            id: sectionButton
                            readonly property var action: root.actions[section.modelData.button]
                            visible: !!action
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 3
                            width: buttonText.implicitWidth + 22
                            height: 26
                            radius: Theme.radiusSmall
                            color: "transparent"
                            border.width: 1
                            border.color: !root.restarting && buttonArea.containsMouse ? Theme.textMuted : Theme.surfaceAlt
                            opacity: root.restarting ? 0.6 : 1

                            Text {
                                id: buttonText
                                anchors.centerIn: parent
                                text: root.restarting ? "Restarting\u2026" : "\u21BB " + (sectionButton.action?.label ?? "")
                                color: Theme.textSecondary
                                font.pixelSize: Theme.textSmall
                            }

                            MouseArea {
                                id: buttonArea
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !root.restarting
                                cursorShape: Qt.PointingHandCursor
                                onClicked: sectionButton.action.run()
                            }
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
