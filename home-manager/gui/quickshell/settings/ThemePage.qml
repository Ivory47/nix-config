import QtQuick
import QtQuick.Controls
import qs.shared

// Every value of Theme.qml, in groups. Changing one writes it to the settings app's file (see
// ThemeStore) and every shell follows. The reset arrow next to a value brings back the default
// from ThemeDefaults.qml.
Item {
    id: root

    readonly property var sections: [
        { title: "Colors", items: [
            { key: "background", label: "Background", note: "Panels, menus and the glass tint", type: "color" },
            { key: "surface", label: "Surface", type: "color" },
            { key: "surfaceAlt", label: "Surface (alternative)", note: "Borders and highlights", type: "color" },
            { key: "text", label: "Text", type: "color" },
            { key: "textSecondary", label: "Text, secondary", type: "color" },
            { key: "textMuted", label: "Text, muted", type: "color" },
            { key: "accent", label: "Accent", type: "color" },
            { key: "green", label: "Green", type: "color" },
            { key: "orange", label: "Orange", type: "color" },
            { key: "red", label: "Red", type: "color" },
            { key: "shadowColor", label: "Shadow", type: "color", alpha: true }
        ]},
        { title: "Status bar", items: [
            { key: "statusBarHeight", label: "Height", type: "number", kind: "int", min: 24, max: 120, note: "Needs a restart of the bar's glass to be exact" },
            { key: "barBorderColor", label: "Border color", type: "color" },
            { key: "barBorderOpacity", label: "Border opacity", type: "number", kind: "real", min: 0, max: 1 },
            { key: "barFillOpacity", label: "Fill opacity", type: "number", kind: "real", min: 0, max: 1, note: "Only visible with the glass off" },
            { key: "osdIndicatorWidth", label: "OSD width", type: "number", kind: "int", min: 60, max: 400, step: 10 }
        ]},
        { title: "Glass", items: [
            { key: "glass", label: "Live glass", type: "bool", note: "Off: no screen capture. May need a restart of the shells" },
            { key: "glassBlurRadius", label: "Blur radius", type: "number", kind: "real", min: 0, max: 40, step: 1, note: "Bar and popups" },
            { key: "scrimBlurRadius", label: "Settings desktop blur", type: "number", kind: "real", min: 0, max: 40, step: 0.5, note: "Blur of the desktop behind the settings" },
            { key: "backdropBlur", label: "Legacy blur", type: "number", kind: "real", min: 0, max: 1, note: "Unused" }
        ]},
        { title: "Shape", items: [
            { key: "radiusSmall", label: "Small radius", type: "number", kind: "int", min: 0, max: 30 },
            { key: "radiusMedium", label: "Medium radius", type: "number", kind: "int", min: 0, max: 30 },
            { key: "radiusLarge", label: "Large radius", type: "number", kind: "int", min: 0, max: 40 }
        ]},
        { title: "Spacing", items: [
            { key: "spacingSmall", label: "Small", type: "number", kind: "int", min: 0, max: 40 },
            { key: "spacingMedium", label: "Medium", type: "number", kind: "int", min: 0, max: 40 },
            { key: "spacingLarge", label: "Large", type: "number", kind: "int", min: 0, max: 60 }
        ]},
        { title: "Typography", items: [
            { key: "textSmall", label: "Small text", type: "number", kind: "int", min: 8, max: 40 },
            { key: "textMedium", label: "Medium text", type: "number", kind: "int", min: 8, max: 40 },
            { key: "textLarge", label: "Large text", type: "number", kind: "int", min: 8, max: 60 }
        ]}
    ]

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

                        delegate: Loader {
                            id: loader
                            required property var modelData
                            width: section.width

                            sourceComponent: modelData.type === "color" ? colorC
                                : modelData.type === "bool" ? switchC : numberC

                            Component { id: colorC; ColorField { spec: loader.modelData } }
                            Component { id: switchC; SwitchField { spec: loader.modelData } }
                            Component { id: numberC; NumberField { spec: loader.modelData } }
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
