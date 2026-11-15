import QtQuick
import Quickshell
import Quickshell.Wayland

// Test background for run.sh, on the Top layer (under the Overlay-layer probe). LOAD_MODE:
//   sweep  coloured bars move across every frame
//   ramp   the whole panel changes brightness every frame
//   pulse  one white bar crosses at constant speed (on-screen lag, pulse.py)
//   flip   two squares toggle black/white in one commit, one behind the probe strip and one in
//          plain view below it (Lucent's analyze.py)
//   anything else: nothing moves
ShellRoot {
    PanelWindow {
        id: win

        readonly property int py: parseInt(Quickshell.env("PROBE_Y") || "252")
        readonly property int ph: parseInt(Quickshell.env("PROBE_H") || "51")
        readonly property string mode: Quickshell.env("LOAD_MODE") || "sweep"
        property bool on: false

        WlrLayershell.namespace: "glassload"
        WlrLayershell.layer: WlrLayer.Top
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: true
            left: true
            right: true
        }
        margins.top: py
        implicitHeight: Math.min(ph + 111, 810 - py)
        color: "#202428"
        mask: Region {}

        Timer {
            interval: 433
            running: win.mode === "flip"
            repeat: true
            onTriggered: win.on = !win.on
        }

        // B: behind the glass strip.
        Rectangle {
            visible: win.mode === "flip"
            x: 300; y: 0; width: 240; height: win.ph
            color: win.on ? "white" : "black"
        }
        // A: plain view.
        Rectangle {
            visible: win.mode === "flip"
            x: 690; y: win.ph + 30; width: 60; height: 60
            color: win.on ? "white" : "black"
        }

        // ramp: the whole panel changes brightness every frame (no capture can be a true duplicate
        // unless the compositor showed the same frame of ours twice).
        Rectangle {
            visible: win.mode === "ramp"
            anchors.fill: parent
            property real v: 0
            color: Qt.rgba(v, v, v, 1)
            SequentialAnimation on v {
                running: win.mode === "ramp"
                loops: Animation.Infinite
                NumberAnimation { from: 0.1; to: 0.9; duration: 700 }
                NumberAnimation { from: 0.9; to: 0.1; duration: 700 }
            }
        }

        // pulse: one white bar crossing at constant speed (for the on-screen lag measurement).
        Rectangle {
            visible: win.mode === "pulse"
            y: 0; width: 150; height: win.height
            color: "white"
            NumberAnimation on x {
                running: win.mode === "pulse"
                from: -200
                to: win.width + 200
                duration: 1700
                loops: Animation.Infinite
            }
        }

        Repeater {
            model: win.mode === "sweep" ? 5 : 0
            Rectangle {
                required property int index
                y: 0
                width: 90
                height: win.height
                color: ["#e53935", "#43a047", "#1e88e5", "#fdd835", "#ffffff"][index]
                NumberAnimation on x {
                    from: -100
                    to: win.width + 100
                    duration: 1300 + index * 370
                    loops: Animation.Infinite
                }
            }
        }
    }
}
