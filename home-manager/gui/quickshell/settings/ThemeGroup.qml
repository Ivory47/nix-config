import QtQuick
import qs.shared

// A collapsed section of ThemeSchema (kind "collapsed": { id, title, note, items }): a header row (click to open
// or close; closed, it shows how many of its settings were changed), then its settings with a line on the left
// that closes it again. `page` is the ThemePage (which are open, the fields to scroll to). Set `width`.
Column {
    id: group

    required property var page
    required property var modelData
    readonly property bool open: !!page.openGroups[modelData.id]
    readonly property int changed: page.changedIn(modelData.items)
    
    Rectangle {
        width: parent.width
        height: 1
        color: Theme.surfaceAlt
    }

    Item {
        id: header
        width: parent.width
        height: 42

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 1
            radius: Theme.radiusSmall
            // (Opaque: nothing translucent over the glass.)
            color: headerArea.containsMouse ? Theme.surface : "transparent"
        }

        Text {
            id: chevron
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            horizontalAlignment: Text.AlignHCenter
            text: group.open ? "\u25BE" : "\u25B8"
            color: Theme.textSecondary
            font.pixelSize: Theme.textMedium
        }

        Column {
            anchors.left: chevron.right
            anchors.leftMargin: Theme.spacingSmall
            anchors.right: badge.visible ? badge.left : parent.right
            anchors.rightMargin: Theme.spacingMedium
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: group.modelData.title
                color: Theme.text
                font.pixelSize: Theme.textMedium
                font.bold: true
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: group.modelData.note || ""
                color: Theme.textMuted
                font.pixelSize: Theme.textSmall - 1
            }
        }

        // Closed: how many settings in it were changed.
        Rectangle {
            id: badge
            visible: !group.open && group.changed > 0
            anchors.right: parent.right
            anchors.rightMargin: 22 + Theme.spacingSmall
            anchors.verticalCenter: parent.verticalCenter
            width: badgeText.implicitWidth + 16
            height: 20
            radius: 10
            color: Theme.accent

            CenteredText {
                id: badgeText
                anchors.centerIn: parent
                text: group.changed + " changed"
                color: Theme.background
                font.pixelSize: Theme.textSmall - 2
                font.bold: true
            }
        }

        MouseArea {
            id: headerArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: page.setGroupOpen(group.modelData.id, !group.open)
        }
    }

    // The settings, only while open (an invisible Item takes no room), with a
    // line on the left: click it to close the group again.
    Item {
        visible: group.open
        width: parent.width
        height: group.open ? groupBody.height : 0

        MouseArea {
            id: collapseLine
            // Centred under the chevron (x 6, width 16: centre 14).
            x: 14 - width / 2
            width: 12
            height: parent.height
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: page.setGroupOpen(group.modelData.id, false)

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: collapseLine.containsMouse ? 3 : 2
                height: parent.height
                radius: 1
                color: collapseLine.containsMouse ? Theme.accent : Theme.surfaceAlt
            }
        }

        Column {
        id: groupBody
        // Clear of the collapse line (centre 14).
        readonly property int indent: 16 + Theme.spacingMedium
        x: groupBody.indent
        width: parent.width - indent

        Repeater {
            model: group.modelData.items

            delegate: Column {
                id: groupItem
                required property var modelData
                width: group.width - groupBody.indent

                // A gap between clusters of settings (schema `gapBefore`).
                Item { width: 1; height: groupItem.modelData.gapBefore ? Theme.spacingLarge : 0 }

                SettingField {
                    id: groupField
                    width: parent.width
                    spec: groupItem.modelData

                    Component.onCompleted: page.fields[groupItem.modelData.key] = groupField
                }
            }
        }
        }
    }
}
