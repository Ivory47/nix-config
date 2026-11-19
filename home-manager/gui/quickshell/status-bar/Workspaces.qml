import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.shared

// Workspaces 1..count: the focused one is a wide accent pill, one with windows a bright dot, an empty
// one a dim dot. A click switches (the Lua config's dispatcher, `hl.dsp.focus`).
Row {
    id: root

    property int count: 5
    spacing: 8

    function occupied(id) {
        const ws = Hyprland.workspaces.values.find(w => w.id === id)
        return !!ws && ws.toplevels.values.length > 0
    }

    Repeater {
        model: root.count

        delegate: Item {
            id: dot
            required property int index
            readonly property int wsId: index + 1
            readonly property bool focused: Hyprland.focusedWorkspace?.id === wsId
            readonly property bool busy: root.occupied(wsId)

            width: pill.width
            height: 20

            Rectangle {
                id: pill
                anchors.verticalCenter: parent.verticalCenter
                width: dot.focused ? 22 : 8
                height: 8
                radius: 4
                color: dot.focused ? Theme.accent : (dot.busy ? Theme.text : Theme.textMuted)
                opacity: dot.focused || dot.busy ? 1 : 0.5
                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -3
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + dot.wsId + " })"])
            }
        }
    }
}
