import QtQuick
import qs.shared

// The glass parameters of a window rule, grouped like the Theme pages (HyprlandStore.paramBlocks: Blur,
// Tone, Rim, Light, Window; each parameter's `block` decides). `values` holds what is set (key -> value); a
// key that is not set shows the plugin's own default, dimmed. `keys` (optional) limits the rows to those
// keys. `readOnly` shows the values without letting them be changed (base config rules). The rows are a
// fixed list built once (a slider being dragged must survive the edits it causes). Set `width`.
Column {
    id: root

    property var values: ({})
    property var keys: null
    property bool readOnly: false

    signal preview(string key, var v)
    signal commit(string key, var v)
    signal cleared(string key)

    function shows(key) {
        return !keys || keys.indexOf(key) >= 0
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

                delegate: ParamRow {
                    required property var modelData
                    visible: root.shows(modelData.key)
                    fieldId: "param." + modelData.key
                    width: block.width
                    spec: modelData
                    readOnly: root.readOnly
                    value: root.values ? root.values[modelData.key] : undefined
                    onPreview: v => root.preview(modelData.key, v)
                    onCommit: v => root.commit(modelData.key, v)
                    onCleared: root.cleared(modelData.key)
                }
            }
        }
    }
}
