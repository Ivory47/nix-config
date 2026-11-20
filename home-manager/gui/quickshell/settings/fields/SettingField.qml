import QtQuick
import qs.core

// The control for one setting of a schema (ThemeSchema, AppSchema): colour, number, switch, ..., by its type.
// Set `spec` and the width; the height follows the control.
Loader {
    id: root

    required property var spec
    // Where the value lives: ThemeStore (the Theme and settings-app pages) or another store with the same
    // calls (value, defaultOf, isSet, set, preview, commit, reset; for a colour also setLive, colorString, openColor).
    property var store: ThemeStore
    // What a reveal looks for (window rules: RuleCard.find).
    property string fieldId: ""

    sourceComponent: spec.type === "color" ? colorC : spec.type === "bool" ? switchC : spec.type === "choice" ? choiceC
        : spec.type === "link" ? linkC : spec.type === "keys" ? keysC : numberC

    // Outlines the row for a moment (after "show in page").
    function flash() {
        if (item)
            item.flash()
    }

    Component { id: colorC; ColorField { spec: root.spec; store: root.store } }
    Component { id: switchC; SwitchField { spec: root.spec; store: root.store } }
    Component { id: choiceC; ChoiceField { spec: root.spec; store: root.store } }
    Component { id: numberC; NumberField { spec: root.spec; store: root.store } }
    Component { id: linkC; LinkField { spec: root.spec; store: root.store } }
    Component { id: keysC; KeysField { spec: root.spec; store: root.store } }
}
