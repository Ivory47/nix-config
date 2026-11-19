import QtQuick
import Quickshell

// Two forms of one widget that must not be open together (an overlay and a window): when one is shown
// the other is hidden, whatever opened it (IPC, a key, another widget). Both need a `shown` property.
//     ExclusiveShown { a: overlay; b: window }
Scope {
    id: root

    property QtObject a: null
    property QtObject b: null

    Connections {
        target: root.a
        function onShownChanged() {
            if (root.a.shown && root.b)
                root.b.shown = false
        }
    }

    Connections {
        target: root.b
        function onShownChanged() {
            if (root.b.shown && root.a)
                root.a.shown = false
        }
    }
}
