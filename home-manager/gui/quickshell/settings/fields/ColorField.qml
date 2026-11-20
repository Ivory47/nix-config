import QtQuick
import QtQuick.Controls
import qs.shared
import qs.core

// A colour: swatch (opens the picker), hex field, and under the row the picker (saturation and
// brightness square, hue bar and, for colours with transparency, an alpha bar). The picker's
// parts are opaque or fully covered by an opaque base: nothing translucent over the glass.
SettingsRow {
    id: root

    readonly property color value: root.store.value(spec.key)
    readonly property bool hasAlpha: !!spec.alpha
    // Only one picker is open at a time: the store holds which colour it is.
    readonly property bool open: root.store.openColor === spec.key

    // The picker's own state (a colour with no saturation has no hue to read back).
    property real h: 0
    property real s: 0
    property real v: 0
    property real a: 1
    property bool dragging: false

    function sync() {
        if (dragging)
            return
        const c = value
        if (c.hsvHue >= 0)
            h = c.hsvHue
        s = c.hsvSaturation
        v = c.hsvValue
        a = c.a
    }
    onValueChanged: sync()
    Component.onCompleted: sync()

    function apply(commit) {
        const str = root.store.colorString(Qt.hsva(h, s, v, hasAlpha ? a : 1), hasAlpha)
        if (commit)
            root.store.set(spec.key, str)
        else
            root.store.setLive(spec.key, str)  // other shells (the bar) show it during the drag
    }

    belowHeight: open ? 150 : 0

    // Keyboard (KeyNav): Enter opens / closes the picker, i types the hex value. The picker's square and
    // bars are stops of their own while it is open (`navPick`).
    // In a colour grid: its cell, where the cursor goes back to when Enter closes the picker.
    property Item navBackTo: null
    function navActivate() {
        root.store.openColor = open ? "" : spec.key
        const back = navBackTo
        return back ? () => back : undefined
    }
    function navEdit() {
        hex.forceActiveFocus()
        hex.selectAll()
    }
    // part "s" (saturation), "v" (brightness), "h" (hue) or "a" (alpha), by `d` (0 to 1).
    function navPick(part, d) {
        const c = x => Math.max(0, Math.min(1, x))
        if (part === "s") s = c(s + d)
        else if (part === "v") v = c(v + d)
        else if (part === "h") h = Math.min(0.9999, c(h + d))
        else a = c(a + d)
        apply(true)
    }

    Row {
        height: 44
        spacing: Theme.spacingMedium

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 22
            radius: Theme.radiusSmall
            // Opaque version of the colour; transparency is shown by the alpha bar.
            color: Qt.rgba(root.value.r, root.value.g, root.value.b, 1)
            border.width: 1
            border.color: root.open ? Theme.text : Theme.surfaceAlt

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.store.openColor = root.open ? "" : root.spec.key
            }
        }

        TextField {
            id: hex
            anchors.verticalCenter: parent.verticalCenter
            width: 104
            height: 28
            leftPadding: 8
            rightPadding: 8
            topPadding: 0
            bottomPadding: 0
            verticalAlignment: TextInput.AlignVCenter
            font.pixelSize: Theme.textSmall
            font.family: "monospace"
            color: Theme.text
            selectByMouse: true
            maximumLength: 9

            readonly property string shown: root.store.colorString(root.value, root.hasAlpha)
            text: shown
            onShownChanged: if (!activeFocus) text = shown

            background: Rectangle {
                radius: Theme.radiusSmall
                color: "transparent"
                border.width: 1
                border.color: hex.activeFocus ? Theme.textMuted : Theme.surfaceAlt
            }

            function accept() {
                if (!/^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(text))
                    text = shown
                else if (!Qt.colorEqual(text, root.value))
                    root.store.set(root.spec.key, text.toLowerCase())
                focus = false
            }
            onAccepted: accept()
            onActiveFocusChanged: if (!activeFocus) accept()
            // The vim keys for leaving a field first (FieldKeys); Esc: the old value.
            function navCancel() { text = shown }
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: event => {
                FieldKeys.press(event, hex)
                if (!event.accepted && event.key === Qt.Key_Escape) {
                    navCancel()
                    focus = false
                    event.accepted = true
                }
            }
        }
    }

    below: Item {
        visible: root.open
        anchors.fill: parent

        // Saturation (right) and brightness (up)
        Rectangle {
            id: sv
            x: 0
            y: 6
            width: 220
            height: 120
            radius: Theme.radiusSmall
            color: Qt.hsva(root.h, 1, 1, 1)
            border.width: 1
            border.color: Theme.surfaceAlt
            clip: true

            // h / l: saturation; H / L: brightness.
            readonly property bool navStop: true
            function navAdjust(dir, big) {
                root.navPick(big ? "v" : "s", dir * 0.02)
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#ffffffff" }
                    GradientStop { position: 1; color: "#00ffffff" }
                }
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: "#00000000" }
                    GradientStop { position: 1; color: "#ff000000" }
                }
            }
            Rectangle {
                x: root.s * (sv.width - 1) - 5
                y: (1 - root.v) * (sv.height - 1) - 5
                width: 10
                height: 10
                radius: 5
                color: "transparent"
                border.width: 2
                border.color: "#ffffff"
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.CrossCursor
                // A drag here picks a colour; the page's Flickable must not take it over.
                preventStealing: true
                function move(mx, my) {
                    root.s = Math.max(0, Math.min(1, mx / (sv.width - 1)))
                    root.v = 1 - Math.max(0, Math.min(1, my / (sv.height - 1)))
                    root.apply(false)
                }
                onPressed: mouse => { root.dragging = true; move(mouse.x, mouse.y) }
                onPositionChanged: mouse => { if (pressed) move(mouse.x, mouse.y) }
                onReleased: { root.dragging = false; root.apply(true) }
            }
        }

        // Hue, and alpha
        Repeater {
            model: root.hasAlpha ? ["h", "a"] : ["h"]

            delegate: Rectangle {
                id: bar
                required property string modelData
                required property int index
                readonly property bool isHue: modelData === "h"
                // h / l: 5° of hue (H / L: 30°), or 2 % alpha (10 %).
                readonly property bool navStop: true
                function navAdjust(dir, big) {
                    root.navPick(modelData, dir * (isHue ? (big ? 1 / 12 : 1 / 72) : (big ? 0.1 : 0.02)))
                }
                x: 236
                y: 6 + index * 34
                width: 200
                height: 20
                radius: Theme.radiusSmall
                border.width: 1
                border.color: Theme.surfaceAlt
                clip: true
                // Hue: the colour wheel as a bar. Alpha: black to the colour (opaque; the bar only
                // shows how far along it is).
                color: "#000000"
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: bar.isHue ? "#ff0000" : "#000000" }
                    GradientStop { position: 1/6; color: bar.isHue ? "#ffff00" : "#000000" }
                    GradientStop { position: 2/6; color: bar.isHue ? "#00ff00" : "#000000" }
                    GradientStop { position: 3/6; color: bar.isHue ? "#00ffff" : "#000000" }
                    GradientStop { position: 4/6; color: bar.isHue ? "#0000ff" : "#000000" }
                    GradientStop { position: 5/6; color: bar.isHue ? "#ff00ff" : "#000000" }
                    GradientStop { position: 1.0; color: bar.isHue ? "#ff0000" : Qt.rgba(root.value.r, root.value.g, root.value.b, 1) }
                }
                Rectangle {
                    x: (bar.isHue ? root.h : root.a) * (bar.width - 1) - 2
                    width: 4
                    height: parent.height
                    color: "#ffffff"
                    border.width: 1
                    border.color: "#000000"
                }
                Text {
                    visible: !bar.isHue
                    anchors.left: parent.right
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: "alpha"
                    color: Theme.textMuted
                    font.pixelSize: Theme.textSmall - 1
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true
                    function move(mx) {
                        const f = Math.max(0, Math.min(1, mx / (bar.width - 1)))
                        if (bar.isHue) root.h = Math.min(f, 0.9999)
                        else root.a = f
                        root.apply(false)
                    }
                    onPressed: mouse => { root.dragging = true; move(mouse.x) }
                    onPositionChanged: mouse => { if (pressed) move(mouse.x) }
                    onReleased: { root.dragging = false; root.apply(true) }
                }
            }
        }
    }
}
