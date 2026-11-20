import QtQuick
import qs.shared

// A section that opens and closes: a line, a header (chevron, title, small note, "N changed" while closed),
// and the content below it (the default property), indented with a line on the left that closes it again.
// It only reports (`toggled(open)`): whoever owns the open state sets `open`. Set `width`.
//   expandable:     false = it cannot open (no chevron, hover or click), as a widget with the default look.
//   toggleOnKeys:   false = the keyboard cursor on the header does not toggle; the owner reacts to
//                   `activated()` (Enter) and `adjusted(dir)` (h / l) and may have navReset() on its own item.
//   line:           false = no indent and no line on the left (the content is a list of its own).
//   headerContent:  more items of the header, e.g. a control at its right (then set `rightItem`: the text and
//                   the badge end before it).
// The header is a stop of the keyboard cursor (KeyNav): Enter opens / closes, l opens, h closes.
Column {
    id: root

    property bool open: false
    property string title: ""
    property string note: ""
    property int changed: 0
    property bool expandable: true
    property bool boldTitle: true
    property bool toggleOnKeys: true
    property bool line: true
    property int headerHeight: 42
    property int bodyBottom: 0
    property Item rightItem: null
    default property alias content: body.data
    property alias headerContent: header.data
    signal toggled(bool open)
    signal activated()
    signal adjusted(int dir)

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.surfaceAlt
    }

    Item {
        id: header
        width: parent.width
        height: root.headerHeight

        readonly property bool navStop: true
        function navActivate() {
            if (root.toggleOnKeys && root.expandable)
                root.toggled(!root.open)
            root.activated()
        }
        function navAdjust(dir) {
            if (root.toggleOnKeys && root.expandable)
                root.toggled(dir > 0)
            root.adjusted(dir)
        }

        // (Opaque: nothing translucent over the glass.)
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 1
            radius: Theme.radiusSmall
            color: root.expandable && area.containsMouse ? Theme.surface : "transparent"
        }

        Chevron {
            id: chevron
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            visible: root.expandable
            open: root.open
        }

        Column {
            anchors.left: chevron.right
            anchors.leftMargin: Theme.spacingSmall
            anchors.right: badge.visible ? badge.left : root.rightItem ? root.rightItem.left : parent.right
            anchors.rightMargin: Theme.spacingMedium
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: root.title
                color: Theme.text
                font.pixelSize: Theme.textMedium
                font.bold: root.boldTitle
            }
            Text {
                visible: text.length > 0
                width: parent.width
                elide: Text.ElideRight
                text: root.note
                color: Theme.textMuted
                font.pixelSize: Theme.textSmall - 1
            }
        }

        // Closed: how many settings in it were changed.
        Rectangle {
            id: badge
            visible: root.expandable && !root.open && root.changed > 0
            anchors.right: root.rightItem ? root.rightItem.left : parent.right
            // (Where the controls of the rows end: the reset arrows' column is to the right.)
            anchors.rightMargin: root.rightItem ? Theme.spacingMedium : 22 + Theme.spacingSmall
            anchors.verticalCenter: parent.verticalCenter
            width: badgeText.implicitWidth + 16
            height: 20
            radius: 10
            color: Theme.accent

            CenteredText {
                id: badgeText
                anchors.centerIn: parent
                text: root.changed + " changed"
                color: Theme.background
                font.pixelSize: Theme.textSmall - 2
                font.bold: true
            }
        }

        // (Under the items of `headerContent`, so that they take their own clicks.)
        MouseArea {
            id: area
            anchors.fill: parent
            enabled: root.expandable
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggled(!root.open)
        }
    }

    // The content, only while open (an invisible Item takes no room).
    Item {
        visible: root.open
        width: parent.width
        height: root.open ? body.height + root.bodyBottom : 0

        // The line on the left, centred under the chevron (x 6, width 16: centre 14).
        MouseArea {
            id: collapseLine
            visible: root.line
            x: 14 - width / 2
            width: 12
            height: body.height
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggled(false)

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
            // Clear of the collapse line (centre 14).
            readonly property int indent: root.line ? 16 + Theme.spacingMedium : 0
            x: indent
            width: parent.width - indent
        }
    }
}
