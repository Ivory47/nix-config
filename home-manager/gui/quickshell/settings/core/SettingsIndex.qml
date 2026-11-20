pragma Singleton

import QtQuick

// The categories of the settings app and the search over all their settings.
//
// The sidebar has top-level `groups` (Theme, Hyprland, ...: a heading each) and under them the categories
// (one page each). A category: id, group, name, icon, description, sections (ThemeSchema's shape); the list
// is in sidebar order (grouped). Its page is the item of the same index in SettingsView.qml's StackLayout.
// To add a top-level group: an entry in `groups` and categories with that `group`. The Theme categories come from ThemeSchema; to add one,
// an entry there and a ThemePage in the StackLayout; its settings are searchable as soon as they are in
// its `sections`.
QtObject {
    id: root

    readonly property var groups: [
        { id: "theme", name: "Theme" },
        { id: "hyprland", name: "Hyprland" },
        { id: "app", name: "Settings app" }
    ]

    function groupName(groupId) {
        return groups.find(g => g.id === groupId)?.name ?? ""
    }

    readonly property var categories: ThemeSchema.categories.concat([
        // (No searchable settings: its page is a list of rules, not fixed settings.)
        { id: "windowRules", group: "hyprland", name: "Window rules", icon: "󰖯", sections: [] }
    ], AppSchema.categories)

    // Asks the settings view to show a setting in its page (a link row: LinkField). SettingsView.jumpTo.
    signal jumpRequested(string catId, string key)

    function indexOf(catId) {
        return categories.findIndex(c => c.id === catId)
    }

    // catId -> the Theme keys of its settings (the sidebar's "changed" dot, "Reset page").
    readonly property var keysByCategory: {
        const out = {}
        for (const e of entries)
            (out[e.catId] = out[e.catId] || []).push(e.spec.key)
        return out
    }

    function keysOf(catId) {
        return keysByCategory[catId] || []
    }

    // One entry per setting, with the text to search in already lowercased.
    readonly property var entries: {
        const out = []
        let order = 0
        for (const c of categories) {
            for (const s of c.sections) {
                for (const { item, place } of ThemeSchema.flatten(s)) {
                    const top = root.groupName(c.group)
                    const where = s.title + (place ? " › " + place : "")
                    out.push({
                        order: order++,
                        catId: c.id,
                        catName: c.name,
                        section: where,
                        spec: item,
                        label: item.label.toLowerCase(),
                        note: (item.note || "").toLowerCase(),
                        // "radiusLarge" -> "radius large", "glassBar.tintStrength" -> "glass bar tint strength"
                        key: item.key.replace(/([a-z])([A-Z])/g, "$1 $2").replace(/\./g, " ").toLowerCase(),
                        keywords: (item.keywords || []).map(k => k.toLowerCase()),
                        place: (where + " " + c.name + " " + top).toLowerCase(),
                        // The headlines: "status bar", "notifications" find everything under them
                        // (the category's name, the section's title, the block or tab within it).
                        sectionTitle: (c.name + " " + s.title).toLowerCase(),
                        groupTitle: place.toLowerCase()
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
        // The section's headline (and the group's), so that searching for it lists what is under it.
        if (e.sectionTitle.startsWith(w) || start.test(e.sectionTitle)) take(90)
        if (e.groupTitle !== "" && (e.groupTitle.startsWith(w) || start.test(e.groupTitle))) take(85)
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
                title: "In " + root.groupName(cat.group) + " › " + cat.name,
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
