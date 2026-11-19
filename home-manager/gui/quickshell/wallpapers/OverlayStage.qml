import QtQuick
import qs.shared

// The middle of the overlay: the pictures (OverlayCard), the plate over the middle one (OverlayPlate) and
// the text for an empty list. Only the ones near the middle load their image (the folder may be large).
Item {
    id: stage

    required property var overlay

    opacity: overlay.shown && !overlay.filterPending ? 1 : 0
    Behavior on opacity {
        NumberAnimation { duration: 180 }
    }

    Repeater {
        model: stage.overlay.entries.length

        delegate: OverlayCard {
            overlay: stage.overlay
            host: stage
        }
    }

    OverlayPlate {
        overlay: stage.overlay
    }

    // Nothing to show: an empty favourites list, or a tag nobody has any more.
    Text {
        visible: stage.overlay.entries.length === 0 && stage.overlay.totalCount > 0
        anchors.centerIn: parent
        horizontalAlignment: Text.AlignHCenter
        text: stage.overlay.filterTag === WallpaperStore.favouriteTag
            ? "No favourites yet.\nPress Tab for all wallpapers, then F on one you like."
            : "No wallpapers with this tag.\nPress Tab for another list."
        color: OnImage.inkA(0.8)
        font.pixelSize: Theme.textLarge
    }
}
