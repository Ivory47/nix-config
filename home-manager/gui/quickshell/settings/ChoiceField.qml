import QtQuick
import qs.shared

// A setting with a few named values (`spec.options`: [{ id, label }]), as a Segmented row.
SettingsRow {
    id: root

    readonly property var value: Theme[spec.key]

    Segmented {
        y: 7
        options: root.spec.options
        current: root.value
        onPicked: id => ThemeStore.set(root.spec.key, id)
    }
}
