import QtQuick
import qs.shared

// A row of options, one chosen: `options` is [{ id, label }], `current` the chosen id. Opaque or
// outline only (it sits over the glass). Reports a click with `picked(id)`.
// With `stretch` every segment is equally wide: the widest label (measured bold, so choosing one never
// changes the sizes) or an equal share of `width`, whichever is more.
Item {
    id: root

    property var options: []
    property var current: ""
    property int segmentHeight: 30
    property bool stretch: false

    signal picked(var id)

    readonly property real padding: stretch ? 12 : 28
    readonly property real fontSize: Theme.textSmall + 1

    // The widest label, bold, with its padding.
    readonly property real widest: {
        let w = 0
        for (let i = 0; i < measure.count; i++) {
            const t = measure.itemAt(i)
            if (t)
                w = Math.max(w, t.implicitWidth)
        }
        return Math.ceil(w) + padding
    }
    readonly property real segmentWidth: options.length > 0 ? Math.max(width / options.length, widest) : 0

    // The width the segments need: equal ones with `stretch`, else each its own.
    readonly property real naturalWidth: {
        if (stretch)
            return widest * options.length
        let w = 0
        for (let i = 0; i < segments.count; i++) {
            const c = segments.itemAt(i)
            if (c)
                w += c.implicitWidth
        }
        return w
    }

    implicitWidth: naturalWidth
    implicitHeight: segmentHeight
    height: segmentHeight

    // (Only measures: never shown.)
    Repeater {
        id: measure
        model: root.stretch ? root.options : []

        delegate: Text {
            required property var modelData
            visible: false
            text: modelData.label
            font.pixelSize: root.fontSize
            font.bold: true
        }
    }

    Row {
        id: row
        spacing: 0

        Repeater {
            id: segments
            model: root.options

            delegate: Chip {
                required property var modelData

                width: root.stretch ? root.segmentWidth : implicitWidth
                text: modelData.label
                selected: root.current === modelData.id
                pill: false
                horizontalPadding: root.padding
                fontSize: root.fontSize
                boldWhenSelected: true
                height: root.segmentHeight
                onClicked: root.picked(modelData.id)
            }
        }
    }
}
