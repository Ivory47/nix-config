import QtQuick
import qs.shared
import qs.controls
import qs.core

// A setting with a few named values (`spec.options`: [{ id, label }]), as a Segmented row.
SettingsRow {
    id: root

    readonly property var value: root.store.value(spec.key)

    // h / l: the previous / next option; Enter: the next one, round again after the last.
    function navAdjust(dir) {
        const o = spec.options
        const i = o.findIndex(x => x.id === value)
        const j = i < 0 ? 0 : Math.max(0, Math.min(o.length - 1, i + dir))
        if (j !== i)
            root.store.set(spec.key, o[j].id)
    }
    function navActivate() {
        const o = spec.options
        root.store.set(spec.key, o[(o.findIndex(x => x.id === value) + 1) % o.length].id)
    }

    Segmented {
        y: 7
        width: Math.max(root.controlColumn, naturalWidth)
        stretch: true
        options: root.spec.options
        current: root.value
        onPicked: id => root.store.set(root.spec.key, id)
    }
}
