pragma Singleton

import QtQuick

// The categories of the settings app and the search over all their settings.
//
// A category: id, name, icon, sections (the same shape as ThemeSchema.sections). Its page is the
// item of the same index in Settings.qml's StackLayout. To add a category: an entry here and a
// page there; its settings are searchable as soon as they are in `sections`.
QtObject {
    id: root

    readonly property var categories: [
        { id: "theme", name: "Theme", icon: "󰏘", sections: ThemeSchema.sections }
    ]

    function indexOf(catId) {
        return categories.findIndex(c => c.id === catId)
    }

    // One entry per setting, with the text to search in already lowercased.
    readonly property var entries: {
        const out = []
        let order = 0
        for (const c of categories) {
            for (const s of c.sections) {
                for (const item of s.items) {
                    out.push({
                        order: order++,
                        catId: c.id,
                        catName: c.name,
                        section: s.title,
                        spec: item,
                        label: item.label.toLowerCase(),
                        note: (item.note || "").toLowerCase(),
                        // "radiusLarge" -> "radius large"
                        key: item.key.replace(/([a-z])([A-Z])/g, "$1 $2").toLowerCase(),
                        keywords: (item.keywords || []).map(k => k.toLowerCase()),
                        place: (s.title + " " + c.name).toLowerCase()
                    })
                }
            }
        }
        return out
    }

    function _escape(w) {
        return w.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
    }

    // How well one word matches one setting, or -1 when it does not match at all.
    function _wordScore(e, w) {
        const start = new RegExp("(^|[^a-z0-9])" + _escape(w))
        let best = -1
        const take = v => { if (v > best) best = v }
        // The label, most weight.
        if (e.label.startsWith(w)) take(100)
        else if (start.test(e.label)) take(80)
        else if (e.label.includes(w)) take(60)
        // The synonyms.
        for (const k of e.keywords) {
            if (k.startsWith(w) || start.test(k)) take(50)
            else if (k.includes(w)) take(40)
        }
        // The property name, the section and category, the note.
        if (start.test(e.key)) take(35)
        else if (e.key.includes(w)) take(30)
        if (e.place.includes(w)) take(25)
        if (e.note.includes(w)) take(20)
        return best
    }

    // All words must match; the score is the sum.
    function _score(e, words) {
        let total = 0
        for (const w of words) {
            const s = _wordScore(e, w)
            if (s < 0)
                return -1
            total += s
        }
        return total
    }

    function _words(query) {
        return query.toLowerCase().split(/\s+/).filter(w => w.length > 0)
    }

    function _matches(query) {
        const words = _words(query)
        if (words.length === 0)
            return []
        const out = []
        for (const e of entries) {
            const s = _score(e, words)
            if (s >= 0)
                out.push({ e: e, s: s })
        }
        return out
    }

    // Number of matches per category: { catId: n }.
    function counts(query) {
        const out = {}
        for (const m of _matches(query))
            out[m.e.catId] = (out[m.e.catId] || 0) + 1
        return out
    }

    // The results, grouped by category: the priority category (the selected one) first, then the
    // others in their order (none with `onlyPriority`). In a group, the best match first, and the
    // page order among equals. A group: { catId, title, primary, entries: [{ catId, key, spec }] }
    // where `spec` is the setting with "Category › Section" put before its note.
    function search(query, priorityId, onlyPriority) {
        const matches = _matches(query)
        if (matches.length === 0)
            return []
        const groups = []
        const ids = categories.map(c => c.id)
        ids.sort((a, b) => (a === priorityId ? -1 : 0) - (b === priorityId ? -1 : 0))
        for (const id of ids) {
            if (onlyPriority && id !== priorityId)
                continue
            const mine = matches.filter(m => m.e.catId === id)
            if (mine.length === 0)
                continue
            mine.sort((a, b) => (b.s - a.s) || (a.e.order - b.e.order))
            const cat = categories.find(c => c.id === id)
            groups.push({
                catId: id,
                title: "In " + cat.name,
                primary: id === priorityId,
                entries: mine.map(m => ({
                    catId: id,
                    key: m.e.spec.key,
                    spec: Object.assign({}, m.e.spec, {
                        note: m.e.catName + " › " + m.e.section
                            + (m.e.spec.note ? " · " + m.e.spec.note : "")
                    })
                }))
            })
        }
        return groups
    }
}
