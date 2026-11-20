pragma Singleton

import QtQuick

// The settings of the settings app itself (not theme): the sidebar group "Settings app". Same shape as
// ThemeSchema's categories (SettingsIndex adds them after Window rules; their ThemePages come last in
// SettingsView's StackLayout). Defaults: AppDefaults; values: AppSettings (saved in the settings file).
QtObject {
    id: root

    readonly property var vimOnly: ({ key: "keyboard.mode", is: "vim" })

    // One key binding: AppSettings.keys.<action>.
    function bind(action, label, note, keywords) {
        return { key: "keys." + action, type: "keys", label: label, note: note || "",
            keywords: ["key", "keys", "binding", "bind", "shortcut", "vim"].concat(keywords || []) }
    }

    readonly property var categories: [
        { id: "keyboard", group: "app", name: "Keyboard", icon: "󰌌", description: "The keys of this settings app", sections: [
            { id: "mode", title: "Keys", items: [
                { key: "keyboard.mode", keywords: ["keyboard", "keys", "vim", "hjkl", "shortcuts", "navigation", "classic", "mouse"], label: "Keys", type: "choice", options: [
                    { id: "vim", label: "Vim keys" }, { id: "classic", label: "Classic" } ],
                    note: "Vim keys: a cursor, the keys below. Classic: typing searches, Up/Down change the category" },
                { key: "keyboard.cursor", showIf: root.vimOnly, keywords: ["cursor", "highlight", "selection", "selected", "outline", "marker"], label: "Cursor", type: "choice", options: [
                    { id: "bar", label: "Bar" }, { id: "hairline", label: "Hairline" }, { id: "corners", label: "Corners" }, { id: "outline", label: "Outline" } ],
                    note: "How the selected row is marked" }
            ] },
            { id: "bindings", title: "Vim keys", note: "Each action can have several keys: Enter or a click opens its list. A key: a character, Ctrl+d, Alt+j, Shift+Tab, Enter, Space, Esc, Up; two characters (gg) one after the other. 1–9 (category) and y / n (delete?) are fixed",
                blocks: [
                { title: "Move", showIf: root.vimOnly, items: [
                    root.bind("down", "Down", "Next row (sidebar: next category)"),
                    root.bind("up", "Up", "Previous row (sidebar: previous category)"),
                    root.bind("next", "Next item", "In a row of several (colour cells, buttons)"),
                    root.bind("previous", "Previous item"),
                    root.bind("halfDown", "Half a page down", "", ["scroll"]),
                    root.bind("halfUp", "Half a page up", "", ["scroll"]),
                    root.bind("top", "Top of the page"),
                    root.bind("bottom", "Bottom of the page"),
                    root.bind("nextCategory", "Next category"),
                    root.bind("previousCategory", "Previous category")
                ] },
                { title: "Change", showIf: root.vimOnly, items: [
                    root.bind("less", "Smaller / previous", "A colour square: less saturation"),
                    root.bind("more", "Larger / next", "In the sidebar: into the page"),
                    root.bind("lessBig", "Much smaller"),
                    root.bind("moreBig", "Much larger"),
                    root.bind("activate", "Press", "Switch, open, press a button; in the sidebar: into the page"),
                    root.bind("edit", "Type the value", "A number, a hex colour, a text"),
                    root.bind("reset", "Reset the row"),
                    root.bind("resetPage", "Reset the page"),
                    root.bind("remove", "Delete a window rule", "Then y to delete"),
                    root.bind("undo", "Undo"),
                    root.bind("redo", "Redo")
                ] },
                { title: "Other", showIf: root.vimOnly, items: [
                    root.bind("search", "Search"),
                    root.bind("onlyThis", "Only this category", "While searching"),
                    root.bind("help", "List of keys"),
                    root.bind("back", "Back", "Clear the search, page to sidebar, close"),
                    root.bind("close", "Close"),
                    root.bind("leaveField", "Leave a text field", "Search, hex, numbers; two letters must come quickly", ["insert", "escape"])
                ] }
            ] }
        ] }
    ]
}
