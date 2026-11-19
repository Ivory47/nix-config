import QtQuick
import qs.shared

// A row of options, one chosen: `options` is [{ id, label }], `current` the chosen id. Opaque or
// outline only (it sits over the glass). Reports a click with `picked(id)`.
Item {
    id: root

    property var options: []
    property var current: ""
    property int segmentHeight: 30

    signal picked(var id)

    implicitWidth: row.implicitWidth
    implicitHeight: segmentHeight
    height: segmentHeight

    Row {
        id: row
        spacing: 0

        Repeater {
            model: root.options

            delegate: Chip {
                required property var modelData

                text: modelData.label
                selected: root.current === modelData.id
                pill: false
                horizontalPadding: 28
                fontSize: Theme.textSmall + 1
                boldWhenSelected: true
                height: root.segmentHeight
                onClicked: root.picked(modelData.id)
            }
        }
    }
}
