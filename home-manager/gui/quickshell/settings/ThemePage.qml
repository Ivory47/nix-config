import QtQuick
import QtQuick.Controls
import qs.shared

// Every value of Theme.qml, in groups. Changing one writes it to the settings app's file (see
// ThemeStore) and every shell follows. The reset arrow next to a value brings back the default
// from ThemeDefaults.qml.
Item {
    id: root

    readonly property var sections: ThemeSchema.sections

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

                    Text {
                        topPadding: section.index === 0 ? 0 : Theme.spacingLarge
                        bottomPadding: 2
                        text: section.modelData.title
                        color: Theme.accent
                        font.pixelSize: Theme.textLarge - 2
                        font.bold: true
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
