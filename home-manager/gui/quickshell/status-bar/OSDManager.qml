import QtQuick

Item {
    id: manager

    property bool showing: false

    BrightnessOSD {
        id: brightnessOSD

        onShowingChanged: {
            if (showing) {
                manager.showing = true
            }
        }

        onHidden: {
            manager.showing = false
        }
    }

    function showBrightness() {
        brightnessOSD.updateBrightness()
    }
}
