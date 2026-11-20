import QtQuick
import qs.shared

// A whole number (spec.kind "int": minus and plus buttons) or a fraction (kind "real": a slider).
SettingsRow {
    id: root

    readonly property real value: Theme[spec.key]
    readonly property bool isInt: spec.kind === "int"
    readonly property real step: spec.step || (isInt ? 1 : 0.01)

    function clamp(v) {
        const s = Math.round(v / step) * step
        return Math.max(spec.min, Math.min(spec.max, Number(s.toFixed(4))))
    }

    function text(v) {
        return isInt ? String(Math.round(v)) : v.toFixed(step < 0.1 ? 2 : 1)
    }

    // Slider (kind "real"): as wide as the control column.
    SettingsSlider {
        visible: !root.isInt
        width: visible ? root.controlColumn : 0
        from: root.spec.min
        to: root.spec.max
        step: root.step
        value: root.value
        decimals: root.step < 0.1 ? 2 : 1
        onMoved: v => ThemeStore.preview(root.spec.key, v)
        onReleased: ThemeStore.commit()
    }

    // Stepper (kind "int")
    Stepper {
        visible: root.isInt
        width: visible ? implicitWidth : 0
        text: root.text(root.value)
        onStepped: d => ThemeStore.set(root.spec.key, root.clamp(root.value + d * root.step))
    }
}
