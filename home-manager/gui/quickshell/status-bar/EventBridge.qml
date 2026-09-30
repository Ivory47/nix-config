import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: bridge

    signal brightnessChanged()

    IpcHandler {
        target: "events"

        function brightnessChanged(): void {
            bridge.brightnessChanged()
        }
    }
}
