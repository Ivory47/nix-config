pragma Singleton

import QtQuick

// The settings app's text fields hand their keys to KeyNav before they type them, so that the vim keys
// for leaving a field (AppSettings.keys.leaveField: Esc, Ctrl+o, Ctrl+c, a quick "jk") and Tab (only this
// category, while searching) work in every field. A field does:
//     Keys.priority: Keys.BeforeItem
//     Keys.onPressed: event => FieldKeys.press(event, <the field>)
// A field may have `navCancel()` (called when it is left without keeping what was typed) and
// `navEnter()` (Enter does that and the field keeps the focus: adding a key on the Keyboard page).
// KeyNav sets `nav` (its `keys`, KeyMap, say which key does what); in Classic mode (or without it) the
// keys go to the field as before.
QtObject {
    property var nav: null

    function press(event, field) {
        event.accepted = false
        if (!nav || !nav.vim)
            return
        const keys = nav.keys
        const view = nav.view
        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && typeof field.navEnter === "function") {
            field.navEnter()
            event.accepted = true
            return
        }
        const a = keys.match(event, ["leaveField", "onlyThis"], 400)
        if (a === "pending")
            return  // the field types the character
        if (a === "onlyThis") {
            if (field === view.searchField && view.searching)
                view.toggleOnlyThis()
            event.accepted = true  // never the focus chain
        } else if (a === "leaveField") {
            // The first of two characters ("j" of "jk") was typed into the field: take it out again.
            const c = keys.chord
            if (c && typeof field.remove === "function" && field.cursorPosition > 0
                    && field.text[field.cursorPosition - 1] === c[0])
                field.remove(field.cursorPosition - 1, field.cursorPosition)
            if (typeof field.navCancel === "function")
                field.navCancel()
            nav.leaveField(field, false)
            event.accepted = true
        }
    }
}
