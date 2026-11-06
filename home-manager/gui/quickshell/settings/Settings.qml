import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.shared
import qs.shared.glass

// The settings app: categories on the left, the page of the chosen category on the right. The
// window, the glass and the opening and closing are GlassPopup's, as for the launcher.
// Open it with `qs -c settings ipc call settings toggle` (the status bar's button does).
GlassPopup {
    id: root
    WlrLayershell.namespace: "settings"

    focusItem: keys

    function close() {
        root.shown = false
    }

    Connections {
        target: Hyprland

        function onFocusedWorkspaceChanged() {
            root.shown = false
        }
    }

    IpcHandler {
        target: "settings"

        // Asked by the Super+C bind (hyprland.lua): close this instead of the focused window.
        // (A function and not a property: a property logs a warning at every change.)
        function isOpen(): bool {
            return root.shown
        }

        function toggle() {
            root.shown = !root.shown
        }

        function show() {
            root.shown = true
        }

        function hide() {
            root.shown = false
        }
    }

    // A click outside the panel closes it.
    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    GlassListPanel {
        x: Math.round(panel.x)
        y: Math.round(panel.y)
        width: panel.width
        height: panel.height

        popup: root
        // No search field: a zero-size item draws no highlight.
        field: noField
        fieldStrength: 0
        listView: categoryList

        Item {
            id: noField
            width: 0
            height: 0
        }
    }

    Rectangle {
        id: panel

        anchors.centerIn: parent
        width: 900
        height: 620

        radius: Theme.radiusLarge
        color: "transparent"
        border.width: 1
        border.color: Theme.surfaceAlt

        // Swallows clicks on the panel itself.
        MouseArea {
            anchors.fill: parent
        }

        FocusScope {
            id: keys
            anchors.fill: parent
            focus: true

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape
                    || (event.key === Qt.Key_C && (event.modifiers & Qt.ControlModifier))) {
                    root.close()
                    event.accepted = true
                } else if (event.key === Qt.Key_Down) {
                    categoryList.currentIndex = Math.min(categoryList.currentIndex + 1, categoryList.count - 1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Up) {
                    categoryList.currentIndex = Math.max(categoryList.currentIndex - 1, 0)
                    event.accepted = true
                }
            }

            Item {
                id: sidebar
                x: Theme.spacingLarge
                y: Theme.spacingLarge
                width: 190
                height: parent.height - 2 * Theme.spacingLarge

                Text {
                    id: title
                    text: "Settings"
                    color: Theme.text
                    font.pixelSize: Theme.textLarge
                    font.bold: true
                    height: 50
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: Theme.spacingMedium
                }

                ListView {
                    id: categoryList
                    anchors.top: title.bottom
                    anchors.topMargin: Theme.spacingSmall
                    anchors.bottom: parent.bottom
                    width: parent.width
                    spacing: Theme.spacingSmall
                    clip: true
                    currentIndex: 0

                    model: [
                        { name: "Theme", icon: "󰏘" }
                    ]

                    delegate: Item {
                        id: cat
                        required property var modelData
                        required property int index
                        readonly property bool hovered: catArea.containsMouse

                        width: categoryList.width
                        height: 44

                        // The glass draws the highlight of the selected and the hovered row.
                        onHoveredChanged: {
                            if (hovered)
                                root.hoveredItem = cat
                            else if (root.hoveredItem === cat)
                                root.hoveredItem = null
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingMedium
                            spacing: Theme.spacingMedium

                            Text {
                                text: cat.modelData.icon
                                color: Theme.text
                                font.pixelSize: Theme.textLarge - 2
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: cat.modelData.name
                                color: Theme.text
                                font.pixelSize: Theme.textMedium
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: catArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: categoryList.currentIndex = cat.index
                        }
                    }
                }
            }

            Rectangle {
                id: divider
                x: sidebar.x + sidebar.width + Theme.spacingMedium
                y: Theme.spacingLarge
                width: 1
                height: parent.height - 2 * Theme.spacingLarge
                color: Theme.surfaceAlt
            }

            StackLayout {
                x: divider.x + 1 + Theme.spacingLarge
                y: Theme.spacingLarge
                width: parent.width - x - Theme.spacingLarge
                height: parent.height - 2 * Theme.spacingLarge
                currentIndex: categoryList.currentIndex

                ThemePage {}
            }
        }
    }
}
