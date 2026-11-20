import QtQuick
import qs.controls

SettingsRow {
    id: root

    readonly property bool value: root.store.value(spec.key)

    // l: on, h: off, Enter: the other.
    function navAdjust(dir) {
        if ((dir > 0) !== value)
            root.store.set(spec.key, dir > 0)
    }
    function navActivate() {
        root.store.set(spec.key, !value)
    }

    Toggle {
        y: 11
        checked: root.value
        onToggled: root.store.set(root.spec.key, !root.value)
    }
}
