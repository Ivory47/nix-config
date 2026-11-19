import QtQuick
import Quickshell
import Quickshell.Io
import qs.shared

// The status bar. Which layout is shown is Theme.barLayout (Settings > Status bar), or what the IPC
// target `bar` set for a quick look (`setLayout <name>`, `cycleLayout`; in memory only, `setLayout ""`
// goes back to the setting). Classic is StatusBar.qml with its own brightness OSD; the others
// (BalancedBar, IslandsBar, NotchBar) draw the indicator themselves from OsdSource.
ShellRoot {
    id: shell

    // The menus of the balanced bar close (a popup such as the launcher opened).
    signal closePanels()

    readonly property var layouts: ["classic", "balanced", "islands", "notch"]
    property string layoutOverride: ""
    readonly property string layout: {
        const l = layoutOverride !== "" ? layoutOverride : Theme.barLayout
        return layouts.indexOf(l) >= 0 ? l : "classic"
    }

    EventBridge {
        id: eventBridge
    }

    // Classic's overlay OSD exists only in that layout.
    Loader {
        id: osdLoader
        active: shell.layout === "classic"
        sourceComponent: OSDManager {}
    }
    readonly property bool osdShowing: osdLoader.item?.showing ?? false

    Variants {
        model: Quickshell.screens

        Loader {
            id: bar
            required property var modelData

            sourceComponent: {
                switch (shell.layout) {
                case "balanced": return balancedC
                case "islands": return islandsC
                case "notch": return notchC
                default: return classicC
                }
            }

            // Classic hides the bar while its OSD shows.
            Binding {
                target: bar.item
                property: "showing"
                value: !shell.osdShowing
                when: shell.layout === "classic" && bar.item !== null
            }

            Component { id: classicC; StatusBar { screen: bar.modelData } }
            Component {
                id: balancedC
                BalancedBar {
                    id: bb
                    screen: bar.modelData
                    Connections {
                        target: shell
                        function onClosePanels() { bb.panelOpen = false }
                    }
                }
            }
            Component { id: islandsC; IslandsBar { screen: bar.modelData } }
            Component { id: notchC; NotchBar { screen: bar.modelData } }
        }
    }

    Connections {
        target: eventBridge

        function onBrightnessChanged() {
            if (shell.layout === "classic")
                osdLoader.item?.showBrightness()
            else
                OsdSource.showBrightness()
        }
    }

    // Part of "one widget at a time" (shared/Widgets.qml): another widget opened, so the bar's panels close.
    IpcHandler {
        target: "widget"

        function closeForOther(): bool {
            shell.closePanels()
            return false
        }
    }

    IpcHandler {
        target: "bar"

        function setLayout(name: string): void {
            shell.layoutOverride = name
        }

        function cycleLayout(): void {
            const i = shell.layouts.indexOf(shell.layout)
            shell.layoutOverride = shell.layouts[(i + 1) % shell.layouts.length]
        }

        function closePanels(): void {
            shell.closePanels()
        }

        function layout(): string {
            return shell.layout
        }
    }
}
