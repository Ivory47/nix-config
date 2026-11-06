import QtQuick
import QtQuick.Controls
import qs.shared

// The search results: the settings that match, as the real controls (change a value right
// here), grouped by category with the selected one first. Each has a button that jumps to the
// setting in its page.
KineticFlickable {
    id: root

    property string query: ""
    // The selected category: its group comes first, and it is the only one with `onlyPriority`.
    property string priorityId: ""
    property bool onlyPriority: false

    signal jump(string catId, string key)

    readonly property var groups: SettingsIndex.search(query, priorityId, onlyPriority)

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
        width: root.width - 16
        spacing: 0

        Repeater {
            model: root.groups

            delegate: Column {
                id: group
                required property var modelData
                required property int index
                width: column.width

                Text {
                    topPadding: group.index === 0 ? 0 : Theme.spacingLarge
                    bottomPadding: 2
                    text: group.modelData.title
                    color: group.modelData.primary ? Theme.accent : Theme.textSecondary
                    font.pixelSize: Theme.textLarge - 2
                    font.bold: true
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.surfaceAlt
                }

                Repeater {
                    model: group.modelData.entries

                    delegate: Item {
                        id: row
                        required property var modelData
                        width: group.width
                        height: field.height

                        SettingField {
                            id: field
                            width: parent.width - 36
                            spec: row.modelData.spec
                        }

                        // Jump to the setting in its page.
                        Rectangle {
                            x: parent.width - 26
                            y: 9
                            width: 26
                            height: 26
                            radius: Theme.radiusSmall
                            color: "transparent"
                            border.width: 1
                            border.color: jumpArea.containsMouse ? Theme.textMuted : Theme.surfaceAlt

                            Text {
                                anchors.centerIn: parent
                                text: "↗"
                                color: jumpArea.containsMouse ? Theme.text : Theme.textSecondary
                                font.pixelSize: Theme.textMedium
                            }

                            MouseArea {
                                id: jumpArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.jump(row.modelData.catId, row.modelData.key)
                            }
                        }
                    }
                }
            }
        }

        Text {
            visible: root.groups.length === 0
            topPadding: Theme.spacingLarge
            text: "No settings match “" + root.query + "”"
                + (root.onlyPriority ? " in this category" : "")
            color: Theme.textMuted
            font.pixelSize: Theme.textMedium
        }
    }
}
