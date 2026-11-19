import QtQuick
import QtQuick.Controls
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
    readonly property alias tagField: tagInput
    // The suggestion that is highlighted (Up / Down in the tag field), -1 for none.
    property int sugIndex: -1

    // Adds the suggestion `i` (and the complete tags typed before it), clears the field, keeps it open.
    function acceptSuggestion(i) {
        const s = suggestionFlow.suggestions[i]
        if (!s)
            return
        const done = tagInput.text.split(",").slice(0, -1)
        root.tagAdded(done.concat([s.tag]).join(","))
        tagInput.text = ""
        sugIndex = -1
    }

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

    component SectionLabel: Text {
        font.pixelSize: Theme.textSmall - 1
        font.bold: true
        font.letterSpacing: 1.2
        color: Theme.textMuted
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

            // ---- colour ---------------------------------------------------------------------
            Column {
                width: parent.width
                spacing: 8

                SectionLabel { text: "COLOUR   ·   ALT + 1–5" }

                Row {
                    spacing: 8
                    height: 38

                    Text {
                        visible: !root.colors
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Reading colours…"
                        font.pixelSize: Theme.textSmall
                        color: Theme.textMuted
                    }

                    Repeater {
                        model: root.colors || []

                        Rectangle {
                            id: ring
                            required property string modelData
                            required property int index
                            readonly property bool chosen: index === root.colorIndex

                            width: 38
                            height: 38
                            radius: 19
                            color: "transparent"
                            border.width: 2
                            border.color: chosen ? Theme.text : (swatchMouse.containsMouse ? Theme.textMuted : "transparent")

                            Rectangle {
                                anchors.centerIn: parent
                                width: 28
                                height: 28
                                radius: 14
                                color: ring.modelData
                            }

                            MouseArea {
                                id: swatchMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.colorPicked(ring.index)
                            }
                        }
                    }
                }

                // What this colour, scheme and mode give.
                Rectangle {
                    width: parent.width
                    height: 66
                    radius: Theme.radiusMedium
                    color: root.roles ? root.roles.background : Theme.surface
                    border.width: 1
                    border.color: Theme.surfaceAlt

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        spacing: 14
                        visible: !!root.roles

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Aa"
                            font.pixelSize: 26
                            font.bold: true
                            color: root.roles ? root.roles.on_background : Theme.text
                        }

                        Repeater {
                            model: [
                                { label: "Primary", fill: "primary", ink: "on_primary" },
                                { label: "Secondary", fill: "secondary", ink: "on_secondary" },
                                { label: "Tertiary", fill: "tertiary", ink: "on_tertiary" }
                            ]

                            Rectangle {
                                required property var modelData
                                anchors.verticalCenter: parent.verticalCenter
                                width: pillText.implicitWidth + 16
                                height: 26
                                radius: 13
                                color: root.roles ? root.roles[modelData.fill] : "transparent"

                                CenteredText {
                                    id: pillText
                                    anchors.centerIn: parent
                                    text: parent.modelData.label
                                    font.pixelSize: Theme.textSmall - 1
                                    color: root.roles ? root.roles[parent.modelData.ink] : Theme.text
                                }
                            }
                        }
                    }
                }
            }

            // ---- scheme and mode ------------------------------------------------------------
            Column {
                width: parent.width
                spacing: 8

                SectionLabel { text: "SCHEME   ·   ALT + ← →   ·   MODE: ALT + M" }

                Rectangle {
                    width: parent.width
                    height: 34
                    radius: Theme.radiusMedium
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.surfaceAlt

                    Repeater {
                        model: [-1, 1]
                        Item {
                            required property int modelData
                            x: modelData < 0 ? 0 : parent.width - width
                            width: 36
                            height: parent.height
                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData < 0 ? "‹" : "›"
                                font.pixelSize: Theme.textLarge
                                color: stepMouse.containsMouse ? Theme.text : Theme.textSecondary
                            }
                            MouseArea {
                                id: stepMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.schemeStepped(parent.modelData)
                            }
                        }
                    }

                    CenteredText {
                        anchors.centerIn: parent
                        text: root.schemeNames[root.schemeType] || root.schemeType
                        font.pixelSize: Theme.textMedium
                        color: Theme.text
                    }
                }

                Row {
                    id: modeRow
                    width: parent.width
                    spacing: 0
                    height: 34

                    Repeater {
                        model: [ { id: "dark", label: "Dark" }, { id: "light", label: "Light" } ]

                        Rectangle {
                            required property var modelData
                            required property int index
                            readonly property bool on: root.mode === modelData.id

                            width: modeRow.width / 2
                            height: modeRow.height
                            radius: Theme.radiusMedium
                            color: on ? Theme.accent : "transparent"
                            border.width: 1
                            border.color: on ? Theme.accent : Theme.surfaceAlt

                            CenteredText {
                                anchors.centerIn: parent
                                text: parent.modelData.label
                                font.pixelSize: Theme.textMedium
                                font.bold: parent.on
                                color: parent.on ? Theme.background : Theme.textSecondary
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.modeSet(parent.modelData.id)
                            }
                        }
                    }
                }
            }

            // ---- tags -----------------------------------------------------------------------
            Column {
                width: parent.width
                spacing: 8

                SectionLabel { text: "TAGS   ·   CTRL + T" }

                Flow {
                    width: parent.width
                    spacing: 6
                    visible: root.tags.filter(t => t !== WallpaperStore.favouriteTag).length > 0

                    Repeater {
                        model: root.tags.filter(t => t !== WallpaperStore.favouriteTag)
                        TagChip {
                            required property string modelData
                            text: modelData
                            removable: true
                            onRemoved: root.tagRemoved(modelData)
                        }
                    }
                }

                TextField {
                    id: tagInput
                    width: parent.width
                    height: 34
                    leftPadding: 10
                    rightPadding: 10
                    placeholderText: "Add a tag, or pick one below (\u2193 Enter)"
                    placeholderTextColor: Theme.textMuted
                    font.pixelSize: Theme.textSmall + 1
                    color: Theme.text
                    selectByMouse: true

                    background: Rectangle {
                        radius: Theme.radiusMedium
                        color: "transparent"
                        border.width: tagInput.activeFocus ? 2 : 1
                        border.color: tagInput.activeFocus ? Theme.accent : Theme.surfaceAlt
                    }

                    onTextChanged: root.sugIndex = -1

                    // Down / Up highlight an existing tag, Enter adds the highlighted one (or what is typed),
                    // Tab adds the highlighted one, or the first.
                    Keys.onPressed: event => {
                        const n = suggestionFlow.suggestions.length
                        if (event.key === Qt.Key_Escape) {
                            root.leaveToSearch()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Down) {
                            root.sugIndex = Math.min(root.sugIndex + 1, n - 1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            root.sugIndex = Math.max(root.sugIndex - 1, -1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Tab) {
                            if (n > 0)
                                root.acceptSuggestion(root.sugIndex >= 0 ? root.sugIndex : 0)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (root.sugIndex >= 0) {
                                root.acceptSuggestion(root.sugIndex)
                            } else {
                                if (text.trim().length > 0)
                                    root.tagAdded(text)
                                text = ""
                            }
                            event.accepted = true
                        }
                    }
                }

                // Tags that exist already: tap to add (narrowed by what is typed).
                Flow {
                    id: suggestionFlow
                    width: parent.width
                    spacing: 6

                    readonly property var suggestions: WallpaperStore.suggestTags(root.knownTags, root.tags, tagInput.text, 8)
                    visible: suggestions.length > 0

                    Repeater {
                        model: suggestionFlow.suggestions
                        TagChip {
                            required property var modelData
                            required property int index
                            text: "+ " + modelData.tag
                            selected: index === root.sugIndex
                            onClicked: root.acceptSuggestion(index)
                        }
                    }
                }
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
