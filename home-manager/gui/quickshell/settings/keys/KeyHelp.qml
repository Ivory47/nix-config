import QtQuick
import qs.shared
import qs.controls
import qs.core

// The list of the settings app's vim keys (KeyNav), shown with ?. Any key closes it. Opaque: it sits over
// the glass.
Rectangle {
    id: root

    KeyMap {
        id: map
    }

    // [keys, text]: the keys as set on the Keyboard page (AppSettings.keys); a pair joins two actions' keys.
    function both(a, b) { return map.shown(a) + "   " + map.shown(b) }
    readonly property var groups: [
        { title: "Move", keys: [
            [both("down", "up"), "Next / previous row (sidebar: category)"],
            [both("next", "previous"), "Next / previous item in a row"],
            [both("halfDown", "halfUp"), "Half a page down / up"],
            [both("top", "bottom"), "Top / bottom of the page"],
            [both("more", "activate"), "From the sidebar into the page"],
            [both("previousCategory", "nextCategory") + "   1–9", "Previous / next / n-th category"] ] },
        { title: "Change", keys: [
            [both("less", "more"), "Smaller / larger, previous / next choice (else: sideways)"],
            [both("lessBig", "moreBig"), "The same in bigger steps"],
            ["", "Colour square: saturation; the bigger steps: brightness"],
            [map.shown("activate"), "Switch, open, press"],
            [map.shown("edit"), "Type the value (a number, a hex colour, a text)"],
            [both("reset", "resetPage"), "Reset the row / the page"],
            [both("undo", "redo"), "Undo / redo"],
            [map.shown("remove"), "Delete a window rule (y to confirm)"] ] },
        { title: "Other", keys: [
            [map.shown("search"), "Search (Enter: into the results, Enter on one: show it)"],
            [map.shown("onlyThis"), "While searching: only this category"],
            [map.shown("leaveField"), "Leave a text field or the search"],
            [map.shown("back"), "Back: search, page, close"],
            [map.shown("close"), "Close"] ] }
    ]

    width: Math.min(640, parent ? parent.width - 2 * Theme.spacingLarge : 640)
    height: list.implicitHeight + 2 * Theme.spacingLarge
    radius: Theme.radiusLarge
    color: Theme.background
    border.width: 1
    border.color: Theme.surfaceAlt

    Column {
        id: list
        x: Theme.spacingLarge
        y: Theme.spacingLarge
        width: parent.width - 2 * Theme.spacingLarge
        spacing: 2

        Repeater {
            model: root.groups

            delegate: Column {
                id: group
                required property var modelData
                width: list.width
                spacing: 2

                BlockTitle {
                    text: group.modelData.title
                }

                Repeater {
                    model: group.modelData.keys

                    delegate: Row {
                        id: line
                        required property var modelData
                        spacing: Theme.spacingMedium

                        Text {
                            width: 190
                            elide: Text.ElideRight
                            text: line.modelData[0]
                            color: Theme.accent
                            font.pixelSize: Theme.textSmall + 1
                            font.bold: true
                        }

                        Text {
                            width: group.width - 190 - Theme.spacingMedium
                            text: line.modelData[1]
                            color: Theme.text
                            font.pixelSize: Theme.textSmall + 1
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        Text {
            topPadding: Theme.spacingMedium
            text: "Any key closes this. The keys can be changed in Settings app › Keyboard."
            color: Theme.textMuted
            font.pixelSize: Theme.textSmall
        }
    }
}
