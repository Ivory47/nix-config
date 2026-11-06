import QtQuick

// The control for one setting of a schema (ThemeSchema): colour, number or switch, by its type.
// Set `spec` and the width; the height follows the control.
Loader {
    id: root

    required property var spec

    sourceComponent: spec.type === "color" ? colorC : spec.type === "bool" ? switchC : numberC

    // Outlines the row for a moment (after "show in page").
    function flash() {
        if (item)
            item.flash()
    }

    Component { id: colorC; ColorField { spec: root.spec } }
    Component { id: switchC; SwitchField { spec: root.spec } }
    Component { id: numberC; NumberField { spec: root.spec } }
}
