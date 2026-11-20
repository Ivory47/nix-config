import QtQuick
import qs.shared
import qs.core

// The vim keys of the settings app (AppSettings.mode "vim"; "classic" keeps SettingsView's own
// handler). SettingsView passes every key that no text field used to `handle(event)`; text fields pass
// theirs first to FieldKeys. Which key does what is AppSettings.keys (KeyMap; the Keyboard page);
// the names below are the default keys.
//
// Two panes: the sidebar (j/k pick the category, l / Enter go into the page) and the page, where a
// cursor sits on one "stop". A stop is any visible item with `navStop: true` (and not `navEnabled:
// false`); they are found by walking the page's items in order (top to bottom, rows of a grid left to
// right), so no list of them has to be kept. A stop may have:
//   navAdjust(dir, big)  h / l (H / L: a bigger step)
//   navActivate()        Enter / Space
//   navReset()           r
//   navEdit()            i (a text field)
//   navHeight            the height the cursor covers (default: its height)
//   navFrame             { x, y, width, height, radius }: the cursor's frame in its own coordinates
//   navFocused()         the cursor came to it (a colour cell closes another open colour)
// navActivate and navEdit may return a function; it is called after the layout settled and the cursor
// goes to the item it returns (a colour cell: into its editor).
// A stop must not be a positioner (Column, Row, Grid): the cursor becomes its child.
// Stops whose rectangles overlap vertically form one line: j / k go to the next line (to the stop nearest
// to the column the cursor was in), w / b to the next / previous stop.
Item {
    id: nav

    required property var view

    // "sidebar" or "page" (the page or, while searching, the results).
    property string pane: "sidebar"
    // The stop under the cursor (null: none yet).
    property Item current: null
    // Shown after a key, hidden when the mouse moves.
    property bool shown: true
    property bool helpOpen: false
    // A rule card asking "Delete this rule? y / n".
    property Item deleting: null
    // The column j / k keep to (x of the centre, in view coordinates).
    property real wantX: -1
    // The last stop of each category (index -> item).
    property var memory: ({})

    readonly property bool vim: AppSettings.vim

    // When a text field last gave the focus back by itself (the hex field on Enter): the Enter that did it
    // still comes here afterwards and must not also press the row.
    property Item focusNow: Window.activeFocusItem
    property Item focusBefore: null
    property real leftFieldAt: 0
    onFocusNowChanged: {
        if (focusBefore && focusBefore !== view && focusNow === view)
            leftFieldAt = Date.now()
        focusBefore = focusNow
    }
    readonly property Item cursorHost: !vim || !shown || helpOpen || view.searchField.activeFocus ? null
        : pane === "sidebar" ? view.categoryList.currentItem : current

    NavCursor {
        target: nav.cursorHost
    }

    // Which key does what (also read by FieldKeys).
    readonly property KeyMap keys: KeyMap {}
    // The sidebar's hint: "? keys" (the first key of `help`).
    readonly property string keyHint: ((AppSettings.keys.help || [])[0] || "") + " keys"
    readonly property var pageActions: Object.keys(AppDefaults.keys).filter(a => a !== "leaveField")
    Component.onCompleted: FieldKeys.nav = nav

    // Finding the stops and scrolling to them.
    NavStops {
        id: geo
        view: nav.view
    }

    function setCurrent(s, keepColumn) {
        if (s && s !== current && typeof s.navFocused === "function")
            s.navFocused()
        current = s
        if (s && !keepColumn)
            wantX = geo.centreX(s)
        if (s && !view.searching)
            memory[view.categoryList.currentIndex] = s
        if (s)
            geo.reveal(s)
    }

    // The cursor's stop, or (after a relayout took it away) the first one.
    function valid(list) {
        return current && list.indexOf(current) >= 0 ? current : null
    }

    // ---- moving

    function enterPage() {
        pane = "page"
        const list = geo.stops()
        const m = memory[view.categoryList.currentIndex]
        setCurrent(!view.searching && m && list.indexOf(m) >= 0 ? m : (list[0] || null))
    }

    function moveLine(dir) {
        const list = geo.stops()
        if (list.length === 0)
            return
        const cur = valid(list)
        if (!cur) {
            setCurrent(list[0])
            return
        }
        const ls = geo.lines(list)
        const i = Math.max(0, Math.min(ls.length - 1, geo.lineOf(ls, cur) + dir))
        if (wantX < 0)
            wantX = geo.centreX(cur)
        setCurrent(geo.nearest(ls[i], wantX), true)
    }

    function moveStop(dir) {
        const list = geo.stops()
        const cur = valid(list)
        const i = cur ? Math.max(0, Math.min(list.length - 1, list.indexOf(cur) + dir)) : 0
        if (list[i])
            setCurrent(list[i])
    }

    // h / l: change the value; on a stop without one (a colour cell, a button) the next one in the line.
    function adjust(dir, big) {
        const list = geo.stops()
        if (!valid(list))
            return
        const s = withFn("navAdjust")
        if (s) {
            s.navAdjust(dir, big)
            return
        }
        const ls = geo.lines(list)
        const line = ls[geo.lineOf(ls, current)]
        const next = line[line.indexOf(current) + dir]
        if (next)
            setCurrent(next)
    }

    function moveEnd(last) {
        const list = geo.stops()
        if (list.length === 0)
            return
        setCurrent(last ? list[list.length - 1] : list[0])
        const f = geo.flickOf(current)
        if (f && !last) {
            f.stopGlide()
            f.contentY = 0
        }
    }

    // J / K: half a page, the cursor goes along.
    function halfPage(dir) {
        const list = geo.stops()
        const cur = valid(list) || list[0]
        const f = geo.flickOf(cur) || geo.flickOf(list[list.length - 1])
        if (!cur || !f)
            return
        const before = f.contentY
        const to = f.clampContentY(before + dir * f.height / 2)
        f.stopGlide()
        f.contentY = to
        const moved = to - before !== 0 ? to - before : dir * f.height / 2
        const y = geo.rectOf(cur).y + moved
        const ls = geo.lines(list)
        let best = ls[0], d = Infinity
        for (const l of ls) {
            const dd = Math.abs(geo.rectOf(l[0]).y - y)
            if (dd < d) {
                d = dd
                best = l
            }
        }
        if (wantX < 0)
            wantX = geo.centreX(cur)
        setCurrent(geo.nearest(best, wantX), true)
    }

    function setCategory(i) {
        const n = view.categoryList.count
        if (i < 0 || i >= n || i === view.categoryList.currentIndex)
            return
        view.categoryList.currentIndex = i
        if (pane === "page")
            Qt.callLater(enterPage)
    }

    // The stop itself or the nearest item around it with the function.
    function withFn(name) {
        for (let s = current; s; s = s.parent)
            if (typeof s[name] === "function")
                return s
        return null
    }

    function call(name, a, b) {
        if (!valid(geo.stops()))
            return
        const s = withFn(name)
        return s ? follow(s[name](a, b)) : undefined
    }

    // A function returned by navActivate / navEdit: after the layout, the cursor goes where it says.
    function follow(r) {
        if (typeof r !== "function")
            return r
        Qt.callLater(() => {
            const to = r()
            if (to)
                setCurrent(to)
        })
        return undefined
    }

    // ---- from outside

    // After a jump (an undo, a link row, a search result): the cursor goes to the setting.
    function placeAt(catIndex, key) {
        placeTimer.catIndex = catIndex
        placeTimer.key = key
        placeTimer.restart()
    }

    Timer {
        id: placeTimer
        property int catIndex: -1
        property string key: ""
        // After the page's scrollTo (which may first open a group: 60 ms).
        interval: 120
        onTriggered: {
            if (!nav.vim || catIndex !== nav.view.categoryList.currentIndex)
                return
            const page = nav.view.pagesStack.children[catIndex]
            const item = page && page.navItemFor ? page.navItemFor(key) : null
            if (!item)
                return
            const inside = []
            geo.collect(item, inside)
            let s = inside[0] || null
            for (let p = item; !s && p; p = p.parent)
                if (p.navStop === true)
                    s = p
            if (s) {
                nav.pane = "page"
                nav.current = s
                nav.wantX = geo.centreX(s)
                nav.memory[catIndex] = s
            }
        }
    }

    // A press of the mouse: the cursor follows it (hidden until the next key).
    function pressedAt(x, y) {
        if (!vim)
            return
        const side = view.categoryList.mapFromItem(view, x, y)
        if (view.categoryList.contains(side)) {
            pane = "sidebar"
            return
        }
        const list = geo.stops()
        let hit = null
        for (const s of list) {
            const r = geo.rectOf(s)
            if (x >= r.x && x < r.x + r.w && y >= r.y && y < r.y + r.h)
                hit = s // the last one: the innermost
        }
        if (hit) {
            pane = "page"
            current = hit
            wantX = geo.centreX(hit)
            if (!view.searching)
                memory[view.categoryList.currentIndex] = hit
        }
    }

    function reset() {
        keys.first = ""
        helpOpen = false
        cancelDelete()
        shown = true
    }

    // "Delete this rule? y / n" on the card around the cursor (dd, or Enter on its delete button).
    function askDelete() {
        const card = withFn("navDelete")
        if (card) {
            card.confirming = true
            deleting = card
        }
    }

    function cancelDelete() {
        if (deleting)
            deleting.confirming = false
        deleting = null
    }

    // ---- the keys

    // Leaving a text field: like Esc (`enter`: like Enter). The search field: Esc clears the search, Enter
    // goes into the results.
    function leaveField(field, enter) {
        const search = field === view.searchField
        view.takeFocus()
        if (search && !enter)
            view.clearSearch()
        else if (search && view.searching)
            enterPage()
        shown = true
    }

    function handle(event) {
        const k = event.key
        const focused = Window.activeFocusItem
        event.accepted = true

        // A field that let Enter through (a TextField's accepted), or one without FieldKeys.
        if (focused && focused !== view) {
            if (k === Qt.Key_Escape || k === Qt.Key_Return || k === Qt.Key_Enter)
                leaveField(focused, k !== Qt.Key_Escape)
            else
                event.accepted = false
            return
        }

        if (k === Qt.Key_Shift || k === Qt.Key_Control || k === Qt.Key_Alt || k === Qt.Key_Meta
                || k === Qt.Key_AltGr || k === Qt.Key_Super_L || k === Qt.Key_Super_R) {
            event.accepted = false
            return
        }
        shown = true

        if (helpOpen) {
            helpOpen = false
            return
        }
        if (deleting) {
            const card = deleting
            cancelDelete()
            if (event.text === "y")
                card.navDelete()
            return
        }

        const a = keys.match(event, pageActions, 0)
        if (a === "pending")
            return
        // The Enter that left a text field must not also press the row.
        if (keys.nameOf(event) === "Enter" && Date.now() - leftFieldAt < 150)
            return
        if (actions[a]) {
            if (pane === "page" || inPage.indexOf(a) < 0)
                actions[a](event)
        } else if (/^[1-9]$/.test(event.text) && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
            setCategory(Number(event.text) - 1)
        } else if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier)) {
            event.accepted = false
        }
        // Any other key: nothing (no type-to-search in this mode).
    }

    // ---- what each action does (AppDefaults.keys has the names; `inPage`: nothing in the sidebar)

    readonly property var inPage: ["next", "previous", "halfDown", "halfUp", "edit", "reset", "remove", "top", "bottom"]
    readonly property var actions: ({
        back: () => {
            if (nav.view.searching) {
                nav.view.clearSearch()
                if (nav.pane === "page")
                    Qt.callLater(nav.enterPage)
            } else if (nav.pane === "page") {
                nav.pane = "sidebar"
            } else {
                nav.view.closeRequested()
            }
        },
        close: () => nav.view.closeRequested(),
        search: () => nav.view.searchField.forceActiveFocus(),
        onlyThis: () => { if (nav.view.searching) nav.view.toggleOnlyThis() },
        help: () => { nav.helpOpen = true },
        undo: () => SettingsHistory.undo(),
        redo: () => SettingsHistory.redo(),
        previousCategory: () => nav.stepCategory(-1),
        nextCategory: () => nav.stepCategory(1),
        // In the sidebar: the category; l (more) and Enter (activate) go into the page.
        down: () => nav.pane === "page" ? nav.moveLine(1) : nav.stepCategory(1),
        up: () => nav.pane === "page" ? nav.moveLine(-1) : nav.stepCategory(-1),
        less: () => { if (nav.pane === "page") nav.adjust(-1, false) },
        lessBig: () => { if (nav.pane === "page") nav.adjust(-1, true) },
        more: () => nav.pane === "page" ? nav.adjust(1, false) : nav.enterPage(),
        moreBig: () => nav.pane === "page" ? nav.adjust(1, true) : nav.enterPage(),
        activate: event => {
            if (nav.pane !== "page")
                nav.enterPage()
            else if (nav.keys.nameOf(event) === "Enter" && nav.view.searching && nav.withFn("navJump"))
                nav.withFn("navJump").navJump()
            else if (nav.valid(geo.stops()) && nav.call("navActivate") === "delete")
                nav.askDelete()
        },
        resetPage: () => {
            const p = nav.view.pagesStack.children[nav.view.categoryList.currentIndex]
            if (p && p.navResetPage && !nav.view.searching)
                p.navResetPage()
        },
        next: () => nav.moveStop(1),
        previous: () => nav.moveStop(-1),
        halfDown: () => nav.halfPage(1),
        halfUp: () => nav.halfPage(-1),
        top: () => nav.moveEnd(false),
        bottom: () => nav.moveEnd(true),
        edit: () => nav.call("navEdit"),
        reset: () => nav.call("navReset"),
        remove: () => { if (nav.valid(geo.stops())) nav.askDelete() }
    })

    function stepCategory(d) {
        setCategory(view.categoryList.currentIndex + d)
    }
}
