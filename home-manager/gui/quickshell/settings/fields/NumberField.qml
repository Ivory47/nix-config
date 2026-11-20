import QtQuick
import qs.shared
import qs.controls
import qs.core

// A whole number (spec.kind "int": minus and plus buttons) or a fraction (kind "real": a slider).
SettingsRow {
    id: root

    readonly property real value: root.store.value(spec.key)
    readonly property bool isInt: spec.kind === "int"
    readonly property real step: spec.step || (isInt ? 1 : 0.01)

    function clamp(v) {
        const s = Math.round(v / step) * step
        return Math.max(spec.min, Math.min(spec.max, Number(s.toFixed(4))))
    }

    // h / l: one step; H / L: 10 steps (5 for whole numbers).
    function navAdjust(dir, big) {
        const n = big ? (isInt ? 5 : 10) : 1
        root.store.set(spec.key, clamp(value + dir * n * step))
    }

    // i: type the value.
    function navEdit() { (isInt ? stepper : slider).edit() }

    function text(v) {
        return isInt ? String(Math.round(v)) : v.toFixed(step < 0.1 ? 2 : 1)
    }

    // Slider (kind "real"): as wide as the control column.
    SettingsSlider {
        id: slider
        visible: !root.isInt
        width: visible ? root.controlColumn : 0
        from: root.spec.min
        to: root.spec.max
        step: root.step
        value: root.value
        decimals: root.step >= 1 ? 0 : root.step < 0.1 ? 2 : 1
        dimmed: root.inherited
        onMoved: v => root.store.preview(root.spec.key, v)
        onReleased: root.store.commit()
        onTyped: v => root.store.set(root.spec.key, v)
    }

    // Stepper (kind "int")
    Stepper {
        id: stepper
        visible: root.isInt
        width: visible ? implicitWidth : 0
        text: root.text(root.value)
        onStepped: d => root.store.set(root.spec.key, root.clamp(root.value + d * root.step))
        onTyped: v => root.store.set(root.spec.key, root.clamp(v))
    }
}
