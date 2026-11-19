import QtQuick
import QtQuick.Controls
import Quickshell.Widgets
import qs.shared

// Over the middle picture (which it does not move with: the pictures glide under it): at the
// top the star and the tags, at the bottom the name, the position in the list, and the colours.
ClippingRectangle {
    id: plate

    required property var overlay

    visible: !!overlay.entry
    x: parent.width / 2 - width / 2
    y: parent.height / 2 - height / 2
    width: overlay.cardW
    height: overlay.cardH
    radius: overlay.cornerRadius
    color: "transparent"
    z: 1000

    // Top: the star and the tags.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: overlay.addingTag ? 140 : 90
        gradient: Gradient {
            GradientStop { position: 0.0; color: OnImage.shadeA(0.66) }
            GradientStop { position: 1.0; color: OnImage.shadeA(0) }
        }
    }

    Row {
        id: tagRow
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.top: parent.top
        anchors.topMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 110
        spacing: 8
        height: 30
        clip: true

        // The star (F): the favourite tag.
        Item {
            width: 32
            height: 30

            Text {
                anchors.centerIn: parent
                text: overlay.favourite ? "★" : "☆"
                color: overlay.favourite ? Theme.orange : (starArea.containsMouse ? OnImage.ink : OnImage.inkA(0.75))
                font.pixelSize: 26
            }

            MouseArea {
                id: starArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: overlay.toggleFavourite()
            }
        }

        Repeater {
            model: overlay.entryTags.filter(t => t !== WallpaperStore.favouriteTag)

            delegate: Chip {
                required property string modelData
                anchors.verticalCenter: parent.verticalCenter
                text: modelData
                removable: true
                onRemoved: if (overlay.entry) WallpaperStore.removeTag(overlay.entry.name, modelData)
                onClicked: overlay.setFilter(modelData)
            }
        }

        // "+ tag": click or T. Becomes a text field.
        Chip {
            visible: !overlay.addingTag
            anchors.verticalCenter: parent.verticalCenter
            text: "+ tag"
            onClicked: overlay.startAddTag()
        }

        // The tag field exists only while a tag is being typed. (A hidden TextField that once had
        // the focus stays the focus item of the key scope and then takes Escape and Ctrl+C, which
        // a text field treats as "copy": the overlay could no longer be closed with them.)
        Loader {
            active: overlay.addingTag
            anchors.verticalCenter: parent.verticalCenter

            sourceComponent: TextField {
                width: 220
                height: 28
                leftPadding: 12
                rightPadding: 12
                topPadding: 0
                bottomPadding: 0
                verticalAlignment: TextInput.AlignVCenter
                selectByMouse: true
                font.pixelSize: Theme.textSmall + 1
                color: Theme.text
                placeholderText: "new tag, or pick one below"
                placeholderTextColor: Theme.textMuted

                background: Rectangle {
                    radius: 14
                    color: OnImage.shadeA(0.6)
                    border.width: 2
                    border.color: Theme.accent
                }

                Component.onCompleted: forceActiveFocus()

                text: overlay.tagText
                onTextEdited: {
                    overlay.tagText = text
                    overlay.sugIndex = -1
                }

                // Esc cancels; Down / Up highlight an existing tag; Enter adds the highlighted
                // one (the field stays open), or what is typed (and closes it); Tab adds the
                // highlighted one, or the first.
                Keys.onPressed: event => {
                    const n = overlay.tagSuggestions.length
                    if (event.key === Qt.Key_Escape) {
                        overlay.finishAddTag("")
                    } else if (event.key === Qt.Key_Down) {
                        overlay.sugIndex = Math.min(overlay.sugIndex + 1, n - 1)
                    } else if (event.key === Qt.Key_Up) {
                        overlay.sugIndex = Math.max(overlay.sugIndex - 1, -1)
                    } else if (event.key === Qt.Key_Tab) {
                        if (n > 0)
                            overlay.pickSuggestion(overlay.sugIndex >= 0 ? overlay.sugIndex : 0)
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (overlay.sugIndex >= 0)
                            overlay.pickSuggestion(overlay.sugIndex)
                        else
                            overlay.finishAddTag(text)
                    } else {
                        return
                    }
                    event.accepted = true
                }
            }
        }
    }

    // The existing tags, to pick from while a tag is being typed: click one, or Down / Up and Enter,
    // or Tab for the first. (On a plate: it is over the picture.)
    Rectangle {
        visible: overlay.addingTag && overlay.tagSuggestions.length > 0
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.top: tagRow.bottom
        anchors.topMargin: 10
        width: Math.min(parent.width - 40, suggestionRow.implicitWidth + 28)
        height: 40
        radius: height / 2
        color: overlay.plateColor
        border.width: 1
        border.color: OnImage.inkA(0.14)
        clip: true

        Row {
            id: suggestionRow
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 14
            spacing: 6

            CenteredText {
                anchors.verticalCenter: parent.verticalCenter
                text: "existing"
                color: OnImage.inkA(0.6)
                font.pixelSize: Theme.textSmall
            }

            Repeater {
                model: overlay.tagSuggestions

                delegate: SegmentChip {
                    required property var modelData
                    required property int index
                    anchors.verticalCenter: parent.verticalCenter
                    height: 32
                    text: modelData.tag
                    count: modelData.count
                    selected: index === overlay.sugIndex
                    onClicked: overlay.pickSuggestion(index)
                }
            }
        }
    }

    // Bottom: the name and the colours.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 140
        gradient: Gradient {
            GradientStop { position: 0.0; color: OnImage.shadeA(0) }
            GradientStop { position: 1.0; color: OnImage.shadeA(0.78) }
        }
    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 28
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        anchors.right: swatches.left
        anchors.rightMargin: 20
        spacing: 4

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: overlay.entry ? overlay.entry.base : ""
            color: OnImage.ink
            font.pixelSize: Theme.textLarge + 4
            font.bold: true
        }

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: overlay.entry
                ? (overlay.selected + 1) + " / " + overlay.entries.length
                  + "  ·  " + overlay.choice.type.replace("scheme-", "").replace(/-/g, " ")
                  + "  ·  " + overlay.choice.mode
                  + (overlay.applyError ? "  ·  " + overlay.applyError
                     : (overlay.busy ? "  ·  applying…"
                        : (!overlay.applied ? "  ·  not applied: Space" : "")))
                : ""
            color: overlay.applyError ? Theme.red : OnImage.inkA(0.72)
            font.pixelSize: Theme.textMedium
        }
    }

    Row {
        id: swatches
        anchors.right: parent.right
        anchors.rightMargin: 28
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        spacing: 12

        Text {
            visible: !overlay.colors
            anchors.verticalCenter: parent.verticalCenter
            text: "reading colours…"
            color: OnImage.inkA(0.6)
            font.pixelSize: Theme.textSmall
        }

        Repeater {
            model: overlay.colors || []

            delegate: Item {
                id: sw
                required property string modelData
                required property int index
                readonly property bool chosen: index === overlay.colorIndex

                width: 46
                height: 46

                Rectangle {
                    anchors.centerIn: parent
                    width: swArea.containsMouse || sw.chosen ? 44 : 38
                    height: width
                    radius: width / 2
                    color: sw.modelData
                    border.width: sw.chosen ? 3 : 1
                    border.color: sw.chosen ? OnImage.ink : OnImage.inkA(0.35)
                    Behavior on width {
                        NumberAnimation { duration: 90 }
                    }
                }

                MouseArea {
                    id: swArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: overlay.pickColor(sw.index)
                }
            }
        }
    }
}
