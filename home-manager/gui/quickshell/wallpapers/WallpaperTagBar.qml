import QtQuick
import qs.shared

// The tag filters of the wallpaper window: the favourites chip (always there), then a row of the other tags (scrolls
// sideways). All the chosen ones must match. `picker` is the WallpaperPicker; set `y` and `width`.
Item {
    id: tagBar

    required property var picker

    height: 28

    readonly property var otherTags: tagBar.picker.wallpapers.tagList.filter(t => t.tag !== WallpaperStore.favouriteTag)
    readonly property int favouriteCount: WallpaperStore.favouriteCount(tagBar.picker.wallpapers.entries.map(e => e.name))

    Chip {
        id: favChip
        y: 1
        text: "\u2605 Favourites"
        count: tagBar.favouriteCount
        selected: tagBar.picker.wallpapers.activeTags.indexOf(WallpaperStore.favouriteTag) >= 0
        onClicked: tagBar.picker.toggleFilter(WallpaperStore.favouriteTag)
    }

    Text {
        visible: tagBar.otherTags.length === 0
        anchors.left: favChip.right
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: "No other tags yet. Select a wallpaper and add some on the right."
        font.pixelSize: Theme.textSmall
        color: Theme.textMuted
    }

    ListView {
        anchors.left: favChip.right
        anchors.leftMargin: 6
        anchors.right: parent.right
        height: parent.height
        orientation: ListView.Horizontal
        spacing: 6
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: tagBar.otherTags

        delegate: Chip {
            required property var modelData
            y: 1
            text: modelData.tag
            count: modelData.count
            selected: tagBar.picker.wallpapers.activeTags.indexOf(modelData.tag) >= 0
            onClicked: tagBar.picker.toggleFilter(modelData.tag)
        }
    }
}
