import QtQuick

// The stops of the settings app's keyboard cursor (see KeyNav.qml): finding them in the page (or the search
// results), putting them in lines, and scrolling one into view. Coordinates are the view's.
QtObject {
    id: root

    required property var view

    function scopeRoot() {
        return view.searching ? view.results : view.pageAt(view.categoryList.currentIndex)
    }

    function collect(item, out) {
        if (!item || !item.visible)
            return
        if (item.navStop === true && item.navEnabled !== false && item.width > 0)
            out.push(item)
        const ch = item.children
        for (let i = 0; i < ch.length; i++)
            collect(ch[i], out)
    }

    // The stops in reading order: top to bottom by line, each line left to right.
    function stops() {
        const out = []
        collect(scopeRoot(), out)
        const ys = new Map(out.map(s => [s, rectOf(s).y]))
        out.sort((a, b) => ys.get(a) - ys.get(b)) // (stable: the item order breaks ties)
        return [].concat(...lines(out))
    }

    function heightOf(s) {
        return s.navHeight !== undefined ? s.navHeight : s.height
    }

    function rectOf(s) {
        const p = s.mapToItem(view, 0, 0)
        return { x: p.x, y: p.y, w: s.width, h: heightOf(s) }
    }

    // Stops (sorted from top to bottom) in lines: [[stop, ...], ...], each line from left to right.
    function lines(list) {
        const out = []
        let top = 0, bottom = -1
        for (const s of list) {
            const r = rectOf(s)
            if (out.length > 0 && r.y < bottom - 1 && r.y + r.h > top + 1) {
                out[out.length - 1].push(s)
                bottom = Math.max(bottom, r.y + r.h)
            } else {
                out.push([s])
                top = r.y
                bottom = r.y + r.h
            }
        }
        for (const l of out)
            l.sort((a, b) => rectOf(a).x - rectOf(b).x)
        return out
    }

    function lineOf(ls, s) {
        for (let i = 0; i < ls.length; i++)
            if (ls[i].indexOf(s) >= 0)
                return i
        return -1
    }

    function centreX(s) {
        const r = rectOf(s)
        return r.x + r.w / 2
    }

    // The stop of a line nearest to a column (x of the centre).
    function nearest(line, wantX) {
        let best = line[0], d = Infinity
        for (const s of line) {
            const dd = Math.abs(centreX(s) - wantX)
            if (dd < d) {
                d = dd
                best = s
            }
        }
        return best
    }

    // The scrolling page around an item (a SettingsPage), or null.
    function flickOf(item) {
        let f = item ? item.parent : null
        while (f && !(f.clampContentY && f.contentItem))
            f = f.parent
        return f
    }

    // Scrolls as little as possible so that the stop is in view (a stop taller than the page: its top).
    function reveal(s) {
        const f = flickOf(s)
        if (!f)
            return
        const y = s.mapToItem(f.contentItem, 0, 0).y
        const h = heightOf(s)
        const m = 24
        let cy = f.contentY
        if (h + 2 * m > f.height || y - m < cy)
            cy = y - m
        else if (y + h + m > cy + f.height)
            cy = y + h + m - f.height
        cy = f.clampContentY(cy)
        if (cy !== f.contentY) {
            f.stopGlide()
            f.contentY = cy
        }
    }
}
