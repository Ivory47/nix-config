import QtQuick
import qs.shared

// A row on a widget's own page that leads to its glass (ThemeSchema `glassLink`: type "link", `look` = the
// widget's GlassLook name in Theme). It says whether the widget follows the default look or has its own
// (and how many of its values it changes), and its button jumps to it on the Glass page.
SettingsRow {
    id: root

    readonly property var look: Theme[spec.look]
    // How many values its own look sets (the file's "<name>.<value>" keys, the choice itself not counted).
    readonly property int changed: Object.keys(ThemeStore.values)
        .filter(k => k.startsWith(spec.look + ".") && k !== spec.look + ".look").length

    note: !look ? "" : !look.own ? "Follows the default look"
        : changed === 0 ? "Own look, nothing changed yet"
        : "Own look, " + changed + (changed === 1 ? " value" : " values") + " changed"

    ActionButton {
        y: 7
        text: "Edit glass ↗"
        onClicked: SettingsIndex.jumpRequested("glass", root.spec.look + ".look")
    }
}
