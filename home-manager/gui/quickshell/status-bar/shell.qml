import QtQuick
import Quickshell
import Quickshell.Io
import qs.shared

// The status bar. Which layout is shown is Theme.barLayout (Settings > Status bar), or what the IPC
// target `bar` set for a quick look (`setLayout <name>`, `cycleLayout`; in memory only, `setLayout ""`
// goes back to the setting). Both layouts (BalancedBar, NotchBar) draw the indicator themselves from
// OsdSource.
ShellRoot {
    id: shell

    // The menus of the balanced bar close (a popup such as the launcher opened).
    signal closePanels()

    readonly property var layouts: ["balanced", "notch"]
    property string layoutOverride: ""
    readonly property string layout: {
        const l = layoutOverride !== "" ? layoutOverride : Theme.barLayout
        return layouts.indexOf(l) >= 0 ? l : "balanced"
    }

    EventBridge {
        id: eventBridge
    }

    Variants {
        model: Quickshell.screens

        Loader {
            id: bar
            required property var modelData

            sourceComponent: {
                switch (shell.layout) {
                case "balanced": return balancedC
                case "notch": return notchC
                default: return balancedC
                }
            }

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
            Component { id: notchC; NotchBar { screen: bar.modelData } }
        }
    }

    Connections {
        target: eventBridge

        function onBrightnessChanged() {
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
