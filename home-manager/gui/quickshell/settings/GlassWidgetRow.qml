import QtQuick
import qs.shared

// One widget (or group of widgets) of the Glass page's "widgets" section (ThemeSchema `widget()`): a line with
// its name and the choice Default look | Own look. With its own look it can open (click the line) to show
// that look in place, indented with a line on the left that closes it again; closed, it shows how many of
// its values it changes. Picking Own opens it. A value it does not set follows the default look.
// `page` is the ThemePage (open state, fields to scroll to, counts). Set `width`.
Column {
    id: row

    required property var page
    required property var widget        // { id, title, note, items: [the choice], blocks }
    readonly property var choice: widget.items[0]
    readonly property bool own: Theme.value(choice.key) === "own"
    readonly property bool open: own && !!page.openGroups[widget.id]
    readonly property int changed: {
        let n = 0
        for (const b of widget.blocks)
            n += page.changedIn(b.items)
        return n
    }

    // Outlined for a moment when found (the page's scrollTo of its choice).
    property bool flashing: false
    function flash() {
        flashing = true
        flashTimer.restart()
    }
    Timer {
        id: flashTimer
        interval: 1400
        onTriggered: row.flashing = false
    }
    Component.onCompleted: page.fields[choice.key] = row

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.surfaceAlt
    }

    Item {
        id: header
        width: parent.width
        height: 52

        // Hover (only when it can open). Opaque: nothing translucent over the glass.
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 1
            radius: Theme.radiusSmall
            color: row.own && headerArea.containsMouse ? Theme.surface : "transparent"
        }

        Text {
            id: chevron
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            horizontalAlignment: Text.AlignHCenter
            text: !row.own ? "" : row.open ? "▾" : "▸"
            color: Theme.textSecondary
            font.pixelSize: Theme.textMedium
        }

        Column {
            anchors.left: chevron.right
            anchors.leftMargin: Theme.spacingSmall
            anchors.right: badge.visible ? badge.left : choiceControl.left
            anchors.rightMargin: Theme.spacingMedium
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: row.widget.title
                color: Theme.text
                font.pixelSize: Theme.textMedium
            }
            Text {
                visible: text.length > 0
                width: parent.width
                elide: Text.ElideRight
                text: row.widget.note || ""
                color: Theme.textMuted
                font.pixelSize: Theme.textSmall - 1
            }
        }

        // Own and closed: how many values its look changes.
        Rectangle {
            id: badge
            visible: row.own && !row.open && row.changed > 0
            anchors.right: choiceControl.left
            anchors.rightMargin: Theme.spacingMedium
            anchors.verticalCenter: parent.verticalCenter
            width: badgeText.implicitWidth + 16
            height: 20
            radius: 10
            color: Theme.accent

            CenteredText {
                id: badgeText
                anchors.centerIn: parent
                text: row.changed + " changed"
                color: Theme.background
                font.pixelSize: Theme.textSmall - 2
                font.bold: true
            }
        }

        // (Under the choice, so that the choice takes its own clicks.)
        MouseArea {
            id: headerArea
            anchors.fill: parent
            enabled: row.own
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.page.setGroupOpen(row.widget.id, !row.open)
        }

        Segmented {
            id: choiceControl
            anchors.right: parent.right
            // (Where the controls of the rows end: the reset arrows' column is to the right.)
            anchors.rightMargin: 22 + Theme.spacingSmall
            anchors.verticalCenter: parent.verticalCenter
            width: 240
            stretch: true
            segmentHeight: 28
            options: row.choice.options
            current: Theme.value(row.choice.key)
            onPicked: id => {
                ThemeStore.set(row.choice.key, id)
                if (id === "own")
                    row.page.setGroupOpen(row.widget.id, true)
            }
        }

        Rectangle {
            visible: row.flashing
            x: -4
            y: 2
            width: parent.width + 8
            height: parent.height - 4
            radius: Theme.radiusMedium
            color: "transparent"
            border.width: 2
            border.color: Theme.accent
        }
    }

    // Its own look, while open: indented, with a line on the left that closes it.
    Item {
        visible: row.open
        width: parent.width
        height: row.open ? body.height + Theme.spacingSmall : 0

        MouseArea {
            id: collapseLine
            // Centred under the chevron (x 6, width 16: centre 14).
            x: 14 - width / 2
            width: 12
            height: body.height
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.page.setGroupOpen(row.widget.id, false)

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: collapseLine.containsMouse ? 3 : 2
                height: parent.height
                radius: 1
                color: collapseLine.containsMouse ? Theme.accent : Theme.surfaceAlt
            }
        }

        Column {
            id: body
            readonly property int indent: 16 + Theme.spacingMedium
            x: indent
            width: parent.width - indent

            Repeater {
                model: row.widget.blocks

                delegate: SettingsBlock {
                    required property var modelData
                    width: body.width
                    page: row.page
                    title: modelData.title || ""
                    items: modelData.items
                }
            }
        }
    }
}
