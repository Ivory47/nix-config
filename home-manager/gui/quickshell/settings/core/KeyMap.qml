import QtQuick
import qs.shared

// The vim keys of the settings app as actions: reads AppSettings.keys (AppDefaults.keys has the format) and
// turns key events into action names for KeyNav. `match(event, actions)` returns the action of the key,
// "" (no binding) or "pending" (the first of two characters, "gg": the next key decides).
// `valid(token)` / `normal(token)` check one key as the Keyboard page adds it, `usedBy` finds clashes.
QtObject {
    id: root

    readonly property var named: ({
        "Enter": [Qt.Key_Return, Qt.Key_Enter], "Space": [Qt.Key_Space], "Esc": [Qt.Key_Escape],
        "Tab": [Qt.Key_Tab, Qt.Key_Backtab], "Backspace": [Qt.Key_Backspace], "Delete": [Qt.Key_Delete],
        "Up": [Qt.Key_Up], "Down": [Qt.Key_Down], "Left": [Qt.Key_Left], "Right": [Qt.Key_Right],
        "Home": [Qt.Key_Home], "End": [Qt.Key_End], "PageUp": [Qt.Key_PageUp], "PageDown": [Qt.Key_PageDown]
    })

    // The first character of a two-character binding while waiting for the second, and when it came.
    property string first: ""
    property real firstAt: 0
    // The two characters the last `match` completed ("gg"), else "".
    property string chord: ""

    // "Ctrl+Shift+Z" -> "Ctrl+Shift+z"; null if it is not a key.
    function normal(token) {
        const parts = token.split("+")
        let key = parts.pop()
        if (key === "" && parts.length > 0 && token.endsWith("+")) {  // "Ctrl++"
            parts.pop()
            key = "+"
        }
        const mods = []
        for (const m of ["Ctrl", "Alt", "Shift"]) {
            const i = parts.findIndex(p => p.toLowerCase() === m.toLowerCase())
            if (i >= 0) {
                mods.push(m)
                parts.splice(i, 1)
            }
        }
        if (parts.length > 0 || key === "")
            return null
        const name = Object.keys(named).find(n => n.toLowerCase() === key.toLowerCase())
            || (key.toLowerCase() === "escape" ? "Esc" : key.toLowerCase() === "return" ? "Enter" : "")
        if (name)
            return mods.concat([name]).join("+")
        if (key.length === 1)
            return mods.length > 0 ? mods.concat([key.toLowerCase()]).join("+") : key
        if (key.length === 2 && mods.length === 0)
            return key  // two characters, one after the other
        return null
    }

    // One key as typed on the Keyboard page ("ctrl+D" -> "Ctrl+d"), or null if it is not one.
    function valid(token) {
        return typeof token === "string" && token.trim().length > 0 && normal(token.trim()) !== null
    }

    // The other actions a key already does where `except` is used ([action names]). In a text field only
    // leaveField and onlyThis count, elsewhere all but leaveField: Esc may be both Back and Leave a field.
    function usedBy(token, except) {
        const n = normal(token)
        const t = table([])
        const where = a => a === "leaveField" ? ["field"] : a === "onlyThis" ? ["field", "page"] : ["page"]
        const mine = where(except)
        return Object.keys(t).filter(a => a !== except && t[a].indexOf(n) >= 0
            && where(a).some(w => mine.indexOf(w) >= 0))
    }

    // The key of an event as a binding token ("j", "J", "Ctrl+d", "Enter", "Shift+Tab"), or "".
    function nameOf(event) {
        const k = event.key
        const mods = event.modifiers
        const ctrl = (mods & Qt.ControlModifier) && !(mods & Qt.AltModifier)
        const alt = (mods & Qt.AltModifier) && !(mods & Qt.ControlModifier)
        const shift = mods & Qt.ShiftModifier
        const named = Object.keys(root.named).find(n => root.named[n].indexOf(k) >= 0)
        const m = []
        if (ctrl) m.push("Ctrl")
        if (alt) m.push("Alt")
        if (named) {
            if (shift || k === Qt.Key_Backtab) m.push("Shift")
            return m.concat([named]).join("+")
        }
        if (ctrl || alt) {
            if (shift) m.push("Shift")
            const letter = k >= Qt.Key_A && k <= Qt.Key_Z ? String.fromCharCode(k - Qt.Key_A + 97)
                : event.text.length === 1 ? event.text.toLowerCase() : ""
            return letter ? m.concat([letter]).join("+") : ""
        }
        const t = event.text
        return t.length === 1 && t.charCodeAt(0) >= 32 && t.charCodeAt(0) !== 127 ? t : ""
    }

    // action -> its normalised tokens, for `actions` (a list of names; all when empty).
    function table(actions) {
        const out = {}
        for (const a in AppSettings.keys) {
            if (actions.length > 0 && actions.indexOf(a) < 0)
                continue
            out[a] = AppSettings.keys[a].map(normal).filter(t => t !== null)
        }
        return out
    }

    // `maxGap` (ms): how soon the second of two characters must come (0: any time).
    function match(event, actions, maxGap) {
        const name = nameOf(event)
        if (!name)
            return ""
        const t = table(actions || [])
        const prev = first
        const late = maxGap > 0 && Date.now() - firstAt > maxGap
        first = ""
        chord = ""
        if (prev && !late) {
            for (const a in t) {
                if (t[a].indexOf(prev + name) >= 0) {
                    chord = prev + name
                    return a
                }
            }
        }
        for (const a in t) {
            if (t[a].some(x => x.length === 2 && !x.includes("+") && x[0] === name && !(x in named))) {
                first = name
                firstAt = Date.now()
                return "pending"
            }
        }
        for (const a in t)
            if (t[a].indexOf(name) >= 0)
                return a
        return ""
    }

    // The binding as shown in the help: "j  Down".
    function shown(action) {
        return (AppSettings.keys[action] || []).join("  ")
    }
}
