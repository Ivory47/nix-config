import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.shared
import qs.shared.glass

// Measuring stand-in for a glass surface: an Overlay-layer strip with the same GlassBackdrop and
// GlassPanel as the status bar, placed at PROBE_Y (logical px), PROBE_H tall. No input.
ShellRoot {
    PanelWindow {
        id: win

        readonly property int py: parseInt(Quickshell.env("PROBE_Y") || "252")
        readonly property int ph: parseInt(Quickshell.env("PROBE_H") || "51")

        WlrLayershell.namespace: "glassprobe"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: true
            left: true
            right: true
        }
        margins.top: py
        implicitHeight: ph
        color: "transparent"
        mask: Region {}

        Item {
            id: content
            anchors.fill: parent

            GlassPanel {
                anchors.fill: parent
                backdrop: backdrop
                style: GlassStyle {}
            }
        }

        GlassBackdrop {
            id: backdrop
            composite: content
            origin: Qt.point(0, win.py)
            blurRadius: Theme.glassBlurRadius
            ipcTarget: "glassprobe"
        }

        // Marks, in the log, the captures that were published (the others were dropped as duplicates).
        Connections {
            target: backdrop.capture
            function onCaptured(serial) { console.log("EVPUB " + serial + " deferred " + backdrop.updatesDeferred); }
        }
    }
}
