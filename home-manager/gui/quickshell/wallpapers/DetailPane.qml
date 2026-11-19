import QtQuick
import Quickshell.Widgets
import qs.shared

// The right side of the wallpaper picker: the selected wallpaper large, its name, the colours
// matugen found in it (one to pick), a live preview of the scheme that colour would give, scheme
// type and light / dark, the tags, and the Apply button. It only shows and reports: the picker
// does the work (signals below). Everything here is opaque or outline-only (it is over the glass).
Item {
    id: root

    // The wallpaper (an entry of WallpaperModel) or null.
    property var entry: null
    property var colors: undefined       // its source colours, undefined while matugen is still reading it
    property int colorIndex: 0
    property string schemeType: "scheme-tonal-spot"
    property string mode: "dark"
    property var roles: undefined      // role -> hex of the scheme that would result, undefined while loading
    property var tags: []                // tags of this wallpaper
    property var knownTags: []           // [{tag, count}] of all wallpapers (for suggestions)
    property bool isCurrent: false
    property bool favourite: false
    // "idle", "running", "ok" or "error", and the message for the last two.
    property string applyState: "idle"
    property string applyMessage: ""
    readonly property alias tagField: tagsSection.tagField
    // The suggestion that is highlighted (Up / Down in the tag field), -1 for none.
    property int sugIndex: -1

    signal colorPicked(int index)
    signal schemeStepped(int delta)
    signal modeSet(string mode)
    signal tagAdded(string text)
    signal tagRemoved(string tag)
    signal favouriteToggled()
    signal applyRequested()
    signal leaveToSearch()

    readonly property var schemeNames: ({
        "scheme-tonal-spot": "Tonal spot",
        "scheme-vibrant": "Vibrant",
        "scheme-expressive": "Expressive",
        "scheme-content": "Content",
        "scheme-fidelity": "Fidelity",
        "scheme-fruit-salad": "Fruit salad",
        "scheme-rainbow": "Rainbow",
        "scheme-neutral": "Neutral",
        "scheme-monochrome": "Monochrome",
        "scheme-smart": "Smart"
    })

    function sizeText(bytes) {
        if (bytes >= 1048576)
            return (bytes / 1048576).toFixed(1) + " MB"
        return Math.max(1, Math.round(bytes / 1024)) + " KB"
    }

    Text {
        visible: !root.entry
        anchors.centerIn: parent
        text: "No wallpaper selected"
        color: Theme.textMuted
        font.pixelSize: Theme.textMedium
    }

    Flickable {
        id: scroll
        visible: !!root.entry
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: applyRow.top
        anchors.bottomMargin: Theme.spacingMedium
        contentWidth: width
        contentHeight: column.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column
            width: scroll.width
            spacing: 12

            ClippingRectangle {
                width: parent.width
                height: Math.round(width * 0.56)
                radius: Theme.radiusMedium
                color: Theme.surface

                Image {
                    anchors.fill: parent
                    source: root.entry ? "file://" + root.entry.path : ""
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 900
                }
            }

            Column {
                width: parent.width
                spacing: 2

                Row {
                    width: parent.width
                    spacing: 8

                    // Favourite: the star (Ctrl+F in the picker).
                    Text {
                        id: star
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.favourite ? "\u2605" : "\u2606"
                        color: root.favourite ? Theme.orange : (starArea.containsMouse ? Theme.text : Theme.textMuted)
                        font.pixelSize: Theme.textLarge + 2

                        MouseArea {
                            id: starArea
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.favouriteToggled()
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - star.width - parent.spacing
                        text: root.entry ? root.entry.base : ""
                        elide: Text.ElideMiddle
                        font.pixelSize: Theme.textLarge - 2
                        font.bold: true
                        color: Theme.text
                    }
                }

                Text {
                    width: parent.width
                    text: root.entry
                        ? root.entry.kind + "  ·  " + root.sizeText(root.entry.size) + (root.isCurrent ? "  ·  current wallpaper" : "")
                        : ""
                    elide: Text.ElideRight
                    font.pixelSize: Theme.textSmall
                    color: Theme.textSecondary
                }
            }

            DetailColour {
                pane: root
            }

            DetailScheme {
                pane: root
            }

            DetailTags {
                id: tagsSection
                pane: root
            }
        }
    }

    // ---- apply ----------------------------------------------------------------------------------
    Column {
        id: applyRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 6
        visible: !!root.entry

        Text {
            width: parent.width
            visible: text.length > 0
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
            text: root.applyState === "running" ? "Applying…"
                : root.applyState === "ok" ? "✓ Applied"
                : root.applyState === "error" ? root.applyMessage : ""
            font.pixelSize: Theme.textSmall
            color: root.applyState === "error" ? Theme.red : (root.applyState === "ok" ? Theme.green : Theme.textSecondary)
        }

        Rectangle {
            width: parent.width
            height: 40
            radius: Theme.radiusMedium
            // (Opaque colours only: nothing translucent over the glass.)
            color: root.applyState === "running" ? Theme.surfaceAlt
                 : (applyMouse.pressed ? Theme.textSecondary : Theme.accent)

            CenteredText {
                anchors.centerIn: parent
                text: "Apply wallpaper     ↵"
                font.pixelSize: Theme.textMedium
                font.bold: true
                color: Theme.background
            }

            MouseArea {
                id: applyMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.applyRequested()
            }
        }
    }
}
