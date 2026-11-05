import QtQuick
import Quickshell
import Quickshell.Wayland

// TEMPORARY test harness for the glass: moving colour on the Bottom layer, behind the status
// bar. Run with `qs -p status-bar/glass-test -d`, stop with `qs kill -p status-bar/glass-test`.
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
                width: 260
                height: parent.height
                color: "#00e0ff"
                SequentialAnimation on x {
                    loops: Animation.Infinite
                    NumberAnimation { from: 0; to: 1100; duration: 4000; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1100; to: 0; duration: 4000; easing.type: Easing.InOutSine }
                }
            }
        }
    }
}
