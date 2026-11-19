import QtQuick
import QtQuick.Controls
import qs.shared

// The grid of wallpaper cards of the wallpaper window. `picker` is the WallpaperPicker (its list, selection and
// look); set `y`, `width` and `height`.
GridView {
    id: grid

    required property var picker

    readonly property int columns: Math.max(2, Math.floor(width / 230))
    cellWidth: Math.floor(width / columns)
    cellHeight: Math.round((cellWidth - 16) * 0.56) + 8 + 8 + 6 + 20

    clip: true
    boundsBehavior: Flickable.StopAtBounds
    currentIndex: -1

    // The window is laid out after it opens and can be resized: keep the wallpaper that is
    // on the screen in view until the user has chosen one.
    onHeightChanged: if (grid.picker.shown && grid.picker.followCurrent) Qt.callLater(grid.picker.showSelected)
    onCellWidthChanged: if (grid.picker.shown && grid.picker.followCurrent) Qt.callLater(grid.picker.showSelected)
    model: grid.picker.wallpapers.filtered
    cacheBuffer: cellHeight * 2

    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
        contentItem: Rectangle {
            implicitWidth: 4
            radius: 2
            color: Theme.surfaceAlt
        }
        background: Item {}
    }

    delegate: WallpaperCard {
        id: card

        width: grid.cellWidth
        height: grid.cellHeight
        decodeWidth: (grid.cellWidth - 16) * grid.picker.devicePixelRatio
        isCurrent: modelData.name === grid.picker.wallpapers.current
        colors: ColorCache.colorsOf(modelData)
        highlight: !grid.picker.glassOn && (index === grid.currentIndex || hovered)
        favourite: WallpaperStore.isFavourite(modelData.name)
        onFavouriteToggled: WallpaperStore.toggleFavourite(modelData.name)

        // The glass highlights the hovered card (hlRect2) and the selected one (hlRect1).
        onHoveredChanged: {
            if (hovered)
                grid.picker.hoveredItem = card
            else if (grid.picker.hoveredItem === card)
                grid.picker.hoveredItem = null
        }

        onActivated: {
            grid.picker.select(index)
            grid.picker.focusSearch()
        }
        onApplied: {
            grid.picker.select(index)
            grid.picker.apply(true)
        }
    }

    Text {
        visible: grid.count === 0
        anchors.centerIn: parent
        horizontalAlignment: Text.AlignHCenter
        text: grid.picker.wallpapers.entries.length === 0
            ? "No images in ~/Pictures/Wallpapers"
            : "No wallpapers match"
        font.pixelSize: Theme.textMedium
        color: Theme.textMuted
    }
}
