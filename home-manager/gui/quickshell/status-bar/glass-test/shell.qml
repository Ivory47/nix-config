import QtQuick
import Quickshell
import Quickshell.Wayland

// TEMPORARY test harness for the glass: a strip of moving colour on the Bottom layer, behind
// the status bar (Top layer). Run with `qs -p status-bar/glass-test -d`, stop with `qs kill`.
ShellRoot {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            WlrLayershell.namespace: "glass-test"
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: 120
            color: "transparent"

            Rectangle {
                id: block
                width: 260
                height: parent.height
                color: "#00e0ff"
                x: 0

                SequentialAnimation on x {
                    loops: Animation.Infinite
                    NumberAnimation { from: 0; to: 1100; duration: 6000; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1100; to: 0; duration: 6000; easing.type: Easing.InOutSine }
                }
            }

            Rectangle {
                x: 700
                width: 140
                height: parent.height
                color: "#ffcc00"
                SequentialAnimation on color {
                    loops: Animation.Infinite
                    ColorAnimation { from: "#ffcc00"; to: "#ff2d95"; duration: 1500 }
                    ColorAnimation { from: "#ff2d95"; to: "#ffcc00"; duration: 1500 }
                }
            }
        }
    }
}
