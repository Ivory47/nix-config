pragma Singleton

import QtQuick

// The default settings of the settings app itself: how it is driven, not how anything looks (the theme's
// defaults are shared/ThemeDefaults.qml). AppSettings lays the settings app's changes over these, the way
// Theme does over ThemeDefaults, and saves the changes in its own file (settings-app.json).
// Edit the defaults here; the settings app never writes this file.
QtObject {
    // "mode": "vim" (a cursor, the keys below, / to search) or "classic" (type to search, Up/Down for the
    // categories, the mouse for the rest). "cursor": how vim mode marks the selected row: "bar",
    // "hairline", "corners" or "outline".
    readonly property var keyboard: ({ mode: "vim", cursor: "bar" })

    // The vim keys, per action (keys/KeyNav.qml): a list of keys, any of them does it. A key is a
    // character ("j", "J", "/"), a named key (Enter, Space, Esc, Tab, Backspace, Delete, Up, Down, Left,
    // Right, Home, End, PageUp, PageDown), either with modifiers ("Ctrl+d", "Ctrl+Shift+z", "Alt+j"), or
    // two characters typed one after the other ("gg"). In a text field only `leaveField` and `onlyThis`
    // count; there two characters must come quickly.
    readonly property var keys: ({
        down: ["j", "Down"], up: ["k", "Up"], next: ["w"], previous: ["b"],
        less: ["h", "Left"], more: ["l", "Right"], lessBig: ["H"], moreBig: ["L"],
        halfDown: ["J", "Ctrl+d"], halfUp: ["K", "Ctrl+u"], top: ["gg"], bottom: ["G"],
        activate: ["Enter", "Space"], edit: ["i"], reset: ["r"], resetPage: ["R"], remove: ["dd"],
        undo: ["u", "Ctrl+z"], redo: ["Ctrl+r", "Ctrl+Shift+z", "Ctrl+y"],
        search: ["/"], onlyThis: ["Tab"], help: ["?"],
        previousCategory: ["["], nextCategory: ["]"],
        back: ["Esc"], close: ["q", "Ctrl+c"], leaveField: ["Esc", "Ctrl+o", "Ctrl+c", "jk"]
    })
}
