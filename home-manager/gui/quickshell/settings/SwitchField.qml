import QtQuick
import qs.shared

SettingsRow {
    id: root

    readonly property bool value: Theme[spec.key]

    Rectangle {
        id: track
        y: 11
        width: 42
        height: 22
        radius: 11
        color: root.value ? Theme.accent : Theme.surface
        border.width: 1
        border.color: Theme.surfaceAlt

        Rectangle {
            x: root.value ? parent.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            radius: 8
            color: root.value ? Theme.background : Theme.textMuted

            Behavior on x { NumberAnimation { duration: 90 } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: ThemeStore.set(root.spec.key, !root.value)
        }
    }
}
