import QtQuick
import QtQuick.Controls
import qs.shared

// The tags of the detail pane: the wallpaper's tags (removable), the field to add one, and the existing tags
// to pick from. `pane` is the DetailPane.
Column {
    id: section

    required property var pane

    width: parent.width
    spacing: 8

    readonly property alias tagField: tagInput

    // Adds the suggestion `i` (and the complete tags typed before it), clears the field, keeps it open.
    function acceptSuggestion(i) {
        const s = suggestionFlow.suggestions[i]
        if (!s)
            return
        const done = tagInput.text.split(",").slice(0, -1)
        pane.tagAdded(done.concat([s.tag]).join(","))
        tagInput.text = ""
        pane.sugIndex = -1
    }

    DetailSectionLabel { text: "TAGS   ·   CTRL + T" }

    Flow {
        width: parent.width
        spacing: 6
        visible: pane.tags.filter(t => t !== WallpaperStore.favouriteTag).length > 0

        Repeater {
            model: pane.tags.filter(t => t !== WallpaperStore.favouriteTag)
            Chip {
                required property string modelData
                text: modelData
                removable: true
                onRemoved: pane.tagRemoved(modelData)
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

        onTextChanged: pane.sugIndex = -1

        // Down / Up highlight an existing tag, Enter adds the highlighted one (or what is typed),
        // Tab adds the highlighted one, or the first.
        Keys.onPressed: event => {
            const n = suggestionFlow.suggestions.length
            if (event.key === Qt.Key_Escape) {
                pane.leaveToSearch()
                event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                pane.sugIndex = Math.min(pane.sugIndex + 1, n - 1)
                event.accepted = true
            } else if (event.key === Qt.Key_Up) {
                pane.sugIndex = Math.max(pane.sugIndex - 1, -1)
                event.accepted = true
            } else if (event.key === Qt.Key_Tab) {
                if (n > 0)
                    section.acceptSuggestion(pane.sugIndex >= 0 ? pane.sugIndex : 0)
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (pane.sugIndex >= 0) {
                    section.acceptSuggestion(pane.sugIndex)
                } else {
                    if (text.trim().length > 0)
                        pane.tagAdded(text)
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

        readonly property var suggestions: WallpaperStore.suggestTags(pane.knownTags, pane.tags, tagInput.text, 8)
        visible: suggestions.length > 0

        Repeater {
            model: suggestionFlow.suggestions
            Chip {
                required property var modelData
                required property int index
                text: "+ " + modelData.tag
                selected: index === pane.sugIndex
                onClicked: section.acceptSuggestion(index)
            }
        }
    }
}
