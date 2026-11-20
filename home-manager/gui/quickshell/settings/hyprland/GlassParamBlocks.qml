import QtQuick
import qs.shared
import qs.controls
import qs.fields

// The glass parameters of a window rule, grouped like the Theme pages (HyprlandStore.paramBlocks: Blur,
// Tone, Rim, Light, Window; each parameter's `block` decides), as the same rows as the Theme pages
// (SettingField) on a GlassParamStore. Of a rule: set `ruleId` (the values are the rule's, live). Of a base
// rule: `readOnly` and `values` (what it uses). A key that is not set shows the plugin's own default, dimmed.
// `keys` (optional) limits the rows to those keys. The rows are a fixed list built once (a slider being
// dragged must survive the edits it causes). Set `width`.
Column {
    id: root

    property string ruleId: ""
    property var values: null
    property var keys: null
    property bool readOnly: false

    function shows(key) {
        return !keys || keys.indexOf(key) >= 0
    }

    GlassParamStore {
        id: paramStore
        ruleId: root.ruleId
        readOnly: root.readOnly
        values: root.values !== null ? root.values : (HyprlandStore.byId(root.ruleId)?.glass.params ?? ({}))
    }

    Repeater {
        model: HyprlandStore.paramBlocks

        delegate: Column {
            id: block
            required property var modelData
            width: root.width
            visible: modelData.params.some(p => root.shows(p.key))

            BlockTitle {
                text: block.modelData.title
            }

            Repeater {
                model: block.modelData.params

                delegate: SettingField {
                    required property var modelData
                    visible: root.shows(modelData.key)
                    fieldId: "param." + modelData.key
                    width: block.width
                    // A parameter that is not set shows the default, dimmed (as a widget's look follows the default look).
                    spec: Object.assign({ inherits: true }, modelData)
                    store: paramStore
                }
            }
        }
    }
}
