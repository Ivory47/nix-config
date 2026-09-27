import QtQuick
import Quickshell

ShellRoot {

    EventBridge {
        id: eventBridge
    }

    OSDManager {
        id: osdManager

        onShowingChanged: {
            statusBars.forEach(bar => bar.showing = !showing)
        }
    }

    property var statusBars: []

    Variants {
        model: Quickshell.screens

        StatusBar {
            required property var modelData

            screen: modelData

            Component.onCompleted: {
                statusBars.push(this)
            }

            Component.onDestruction: {
                statusBars.splice(statusBars.indexOf(this), 1)
            }
        }
    }

    Connections {
        target: eventBridge

        function onBrightnessChanged() {
            osdManager.showBrightness()
        }
    }
}
