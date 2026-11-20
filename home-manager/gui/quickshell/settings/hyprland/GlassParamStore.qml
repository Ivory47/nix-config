import QtQuick
import qs.core

// The glass parameters of one window rule as a store for the settings fields (`SettingsRow.store`: the same
// calls as ThemeStore, so NumberField, ColorField, ... edit a rule's `lucent_glass` like a Theme value).
// A key is a lucent_glass key ("frost"). `values` is what is set (key -> value); a key that is not set reads
// as the plugin's default (`def`) and is not `isSet`. Changes go to HyprlandStore, which writes the file.
// `readOnly` (base config rules): nothing changes; `values` is what the rule effectively uses.
QtObject {
    required property string ruleId
    property var values: ({})
    property bool readOnly: false
    // Which colour's picker is open (a colour parameter of this rule).
    property string openColor: ""

    function defaultOf(key) {
        return HyprlandStore.glassParams.find(p => p.key === key)?.def
    }
    function value(key) {
        const v = values ? values[key] : undefined
        return v !== undefined ? v : defaultOf(key)
    }
    function isSet(key) {
        return !!values && values[key] !== undefined
    }
    function preview(key, v) {
        if (!readOnly)
            HyprlandStore.previewParam(ruleId, key, v)
    }
    function setLive(key, v) { preview(key, v) }
    function commit() {
        if (!readOnly)
            HyprlandStore.commit()
    }
    function set(key, v) {
        if (!readOnly)
            HyprlandStore.setParam(ruleId, key, v)
    }
    function reset(key) {
        if (!readOnly)
            HyprlandStore.clearParam(ruleId, key)
    }
    function colorString(c, alpha) {
        return ThemeStore.colorString(c, alpha)
    }
}
