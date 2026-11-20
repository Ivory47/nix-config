import QtQuick
import QtQuick.Controls
import qs.shared

// A scrolling page of the settings app: a KineticFlickable (touchpad momentum) with the slim scroll bar and
// one Column for the content. Put the content inside it (it goes into `column`); set `spacing`. The
// column is inset by 6 px (a row is outlined 4 px outside its edges) and 16 px narrower than the page.
KineticFlickable {
    id: page

    property real spacing: 0
    default property alias content: pageColumn.data
    readonly property alias column: pageColumn

    contentWidth: width
    contentHeight: pageColumn.implicitHeight + Theme.spacingLarge
    clip: true

    ScrollBar.vertical: ScrollBar {
        id: bar
        width: 6
        policy: ScrollBar.AsNeeded
        // (A custom handle: AsNeeded only hides the style's own, so it hides itself while
        // everything fits, size 1 = all of the content is in view.)
        contentItem: Rectangle {
            visible: bar.size < 1
            implicitWidth: 4
            radius: 2
            color: Theme.surfaceAlt
            opacity: bar.active ? 1 : 0.6
        }
        background: Item {}
    }

    // Scrolls so that `item` (anywhere inside the page) is near the top. `gentle`: only when it is not
    // completely in view already.
    function show(item, gentle) {
        const y = item.mapToItem(contentItem, 0, 0).y
        if (gentle && y >= contentY && y + item.height <= contentY + height)
            return
        stopGlide()
        contentY = clampContentY(y - 40)
    }

    Column {
        id: pageColumn
        x: 6
        width: page.width - 16
        spacing: page.spacing
    }
}
