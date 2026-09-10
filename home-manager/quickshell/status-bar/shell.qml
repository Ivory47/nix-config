import QtQuick
import Quickshell

ShellRoot {

    EventBridge {
        id: eventBridge
    }

    OSDManager {
        id: osdManager

        onShowingChanged: {
            statusBar.showing = !showing
        }
    }

    StatusBar {
        id: statusBar
    }

    Connections {
        target: eventBridge

        function onBrightnessChanged() {
            osdManager.showBrightness()
        }
    }

}
