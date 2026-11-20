pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.shared
import qs.core

// The Hyprland category of the settings app: window rules (with the Lucent glass parameters) that
// are kept OUTSIDE the base config, so that changing them never touches hyprland.lua.
//
//  - The rules are written to `hyprland-settings.lua`, next to the source of hyprland.lua in the repo
//    (the same place and the same idea as hyprmod's hyprland-gui.lua; the file is in .gitignore).
//    hyprland.lua loads it LAST (`dofile` at its end), so a rule here overrides a rule of the base
//    config for the same windows (a later rule wins: checked). The file is generated: it holds the
//    rules as Lua and, in a comment, the same rules as JSON, which is what this store reads back.
//  - After every change (a short pause after the last one) the file is written and Hyprland is told to
//    `hyprctl reload`, which re-reads the config and re-applies the rules to windows that are already
//    open (checked in a nested Hyprland), so no `hms` is needed. `hyprctl configerrors` is read
//    afterwards and its lines about this file are shown.
//  - The base config's own rules are listed read-only (parsed from the text of hyprland.lua, only
//    to show them and to start an override from them). A base rule with glass can FOLLOW THE DEFAULT
//    LOOK (`follow`, by rule name): the file then gets a rule with the same match whose lucent_glass is
//    the base rule's own blur radius, quality, corner radius and opacity plus the default look
//    (`defaultLook`, from Theme.glassDefault and Background: the settings app's Glass page). It comes
//    before the rules made here (they still win) and is put in the global table LucentGlassFollowers
//    under the base rule's name, so that hyprland.lua's on/off bind can switch it too.
//  - When the default look changes, the file is written again if something follows it.
//
// A rule: { id, name, enabled, match: { class, title, initial_class, initial_title, float },
//           glass: { mode: "inherit" | "default" | "custom" | "off", params: { <key>: value } } }
//  - match: a Lua regex (RE2) per field; `float` is "" (any), "yes" or "no". A rule needs one.
//  - glass "inherit": no glass effect from this rule; "off": `lucent_glass = "false"` (switches the base
//    config's glass off for these windows); "custom": the parameters set in `params` (the others keep
//    the plugin's defaults; no parameter at all is a plain blur); "default": the default look, with the
//    rule's own blur radius, quality, corner radius and opacity from `params` (the look keys are ignored).
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""
    // (The environment variables are for tests, to keep them away from the real files.)
    readonly property string path: Quickshell.env("HYPRLAND_SETTINGS_FILE")
        || (home + "/src/nix-config/home-manager/gui/hyprland/hyprland-settings.lua")
    // Where the plugin is installed: without it `lucent_glass` is an unknown key (a config error).
    readonly property string pluginPath: "/etc/hypr/plugins/liblucent.so"

    property var rules: []
    readonly property var modes: ["inherit", "default", "custom", "off"]

    // ---- the default look -----------------------------------------------------------------------

    // The lucent_glass keys a rule keeps for itself when it follows the default look (the rest are
    // the look).
    readonly property var ownKeys: ["radius", "taps", "corner_radius", "opacity"]

    // The default look (the settings app's Glass page) as lucent_glass parameters.
    readonly property var defaultLookParams: {
        const out = {}
        for (const g of GlassParams.look) {
            const v = Theme.glassDefault[g.themeKey]
            out[g.key] = g.type === "color" ? ThemeStore.colorString(v, false) : v
        }
        return out
    }
    readonly property string defaultLook: glassParams
        .filter(p => defaultLookParams[p.key] !== undefined)
        .map(p => p.key + "=" + (p.type === "color" ? defaultLookParams[p.key] : RuleLua.num(defaultLookParams[p.key])))
        .join(" ")

    // What a rule's glass really uses for each key: the default look's values when it follows it
    // (except its own keys), else its params. A key it leaves out is not here (the plugin's `def`).
    function effectiveParams(params, followsDefault) {
        if (!followsDefault)
            return params
        const out = Object.assign({}, defaultLookParams)
        for (const k of ownKeys)
            if (params[k] !== undefined)
                out[k] = params[k]
        return out
    }
    // The look the file was last written with (from its data), to write it again only on a real change.
    property string writtenLook: ""
    // The base rules (by name) that follow the default look.
    property var follow: []

    readonly property bool usesDefault: follow.length > 0 || rules.some(r => r.enabled && r.glass.mode === "default")

    function follows(name) {
        return follow.indexOf(name) >= 0
    }

    function setFollow(name, on) {
        const rest = follow.filter(n => n !== name)
        follow = on ? rest.concat([name]) : rest
        commit()
    }

    // The own keys of a set of parameters, then the default look.
    function withDefaultLook(params) {
        const parts = []
        for (const p of glassParams)
            if (ownKeys.indexOf(p.key) >= 0 && params[p.key] !== undefined)
                parts.push(p.key + "=" + RuleLua.num(params[p.key]))
        parts.push(defaultLook)
        return parts.join(" ")
    }

    onDefaultLookChanged: lookTimer.restart()
    Timer {
        id: lookTimer
        interval: 600
        onTriggered: {
            if (root.usesDefault && root.defaultLook !== root.writtenLook)
                root.writeNow()
        }
    }
    // The ids in order. Assigned only when the list of ids changes, so that a list built from it does
    // not rebuild its rows (and take the focus out of a text field) at every keystroke.
    property var ruleIds: []
    onRulesChanged: {
        const ids = rules.map(r => r.id)
        if (JSON.stringify(ids) !== JSON.stringify(ruleIds))
            ruleIds = ids
    }

    // "idle", "saving", "reloading", "ok" or "error", and the text for the last two.
    property string status: "idle"
    property string message: ""

    // The parameters of the glass (the keys of the `lucent_glass` rule; see the Lucent README). `def`
    // is what the plugin uses when the key is left out; `type: "color"` takes #rrggbb. `block` groups
    // them on the page (in this order: `paramBlocks`), like the Theme pages' Tone / Rim / Light.
    readonly property var glassParams: {
        const fromLook = g => Object.assign({}, g, { note: g.ruleNote ?? g.note })
        const own = [
            { block: "Blur", key: "radius", label: "Radius", min: 0, max: 100, step: 1, def: 16, note: "Blur strength, in pixels" },
            { block: "Blur", key: "taps", label: "Quality", min: 1, max: 48, step: 1, def: 32, note: "Samples per side: lower is cheaper" },
            { block: "Window", key: "corner_radius", label: "Corner radius", min: 0, max: 40, step: 1, def: 6, note: "Left out: the window's own rounding (6)" },
            { block: "Window", key: "opacity", label: "Opacity", min: 0, max: 1, step: 0.05, def: 1, note: "Below 1 the sharp background shows through" }
        ]
        return own.slice(0, 2).concat(GlassParams.look.map(fromLook), own.slice(2))
    }

    // [{ title, params }] in the order of glassParams.
    readonly property var paramBlocks: {
        const out = []
        for (const p of glassParams) {
            let b = out.find(x => x.title === p.block)
            if (!b)
                out.push(b = { title: p.block, params: [] })
            b.params.push(p)
        }
        return out
    }

    // ---- editing --------------------------------------------------------------------------------

    function byId(id) {
        return rules.find(r => r.id === id)
    }

    property int _counter: 0
    function newId() {
        return "r" + Date.now().toString(36) + (_counter++).toString(36)
    }

    function emptyRule() {
        return {
            id: newId(), name: "", enabled: true,
            match: { class: "", title: "", initial_class: "", initial_title: "", float: "" },
            effects: [],
            glass: { mode: "custom", params: {} }
        }
    }

    // The other effects of a rule (everything but lucent_glass, e.g. `float = true`): [{ key, value }],
    // the value being Lua source, written as it is.
    function cleanEffects(list) {
        if (!Array.isArray(list))
            return []
        return list.filter(e => e && typeof e.key === "string" && /^[A-Za-z_]\w*$/.test(e.key)
                                && e.key !== "lucent_glass" && e.key !== "name" && e.key !== "match")
                   .map(e => ({ key: e.key, value: String(e.value ?? "") }))
    }

    // Adds a rule at the top and returns its id. `base` (optional) is merged over an empty rule.
    function addRule(base) {
        const r = Object.assign(emptyRule(), base || {})
        // Complete what `base` left out (a match with only some keys, a glass without parameters).
        r.match = Object.assign(emptyRule().match, (base && base.match) || {})
        const g = (base && base.glass) || {}
        r.glass = {
            mode: root.modes.indexOf(g.mode) >= 0 ? g.mode : "custom",
            params: (g.params && typeof g.params === "object") ? g.params : {}
        }
        r.effects = cleanEffects(base && base.effects)
        r.id = newId()
        rules = [r].concat(rules)
        commit()
        return r.id
    }

    function duplicate(id) {
        const r = byId(id)
        if (!r)
            return ""
        const copy = JSON.parse(JSON.stringify(r))
        copy.id = newId()
        copy.name = r.name ? r.name + " (copy)" : ""
        const at = rules.indexOf(r)
        const next = rules.slice()
        next.splice(at + 1, 0, copy)
        rules = next
        commit()
        return copy.id
    }

    function remove(id) {
        rules = rules.filter(r => r.id !== id)
        commit()
    }

    // Changes a copy of the rule with `fn(rule)` and puts it in place. Does not write: call commit()
    // (the sliders call it when released; most other changes go through set*).
    function modify(id, fn) {
        const next = JSON.parse(JSON.stringify(rules))
        const r = next.find(x => x.id === id)
        if (!r)
            return
        fn(r)
        rules = next
    }

    function setName(id, v) { modify(id, r => { r.name = v }); commit() }
    function setEnabled(id, v) { modify(id, r => { r.enabled = v }); commit() }
    function setMatch(id, key, v) { modify(id, r => { r.match[key] = v }); commit() }
    function setEffect(id, index, v) { modify(id, r => { if (r.effects[index]) r.effects[index].value = v }); commit() }
    function removeEffect(id, index) { modify(id, r => { r.effects.splice(index, 1) }); commit() }
    function setMode(id, mode) { modify(id, r => { r.glass.mode = mode }); commit() }
    // A glass parameter: `preview` while a slider is dragged (nothing is written), then commit().
    function previewParam(id, key, v) { modify(id, r => { r.glass.params[key] = v }) }
    function setParam(id, key, v) { previewParam(id, key, v); commit() }
    function clearParam(id, key) { modify(id, r => { delete r.glass.params[key] }); commit() }
    function clearParams(id) { modify(id, r => { r.glass.params = {} }); commit() }

    // ---- checking -------------------------------------------------------------------------------

    function hasMatch(r) {
        const m = r.match
        return !!(m.class || m.title || m.initial_class || m.initial_title || m.float)
    }

    function validRegex(s) {
        if (!s)
            return true
        try {
            new RegExp(s)
            return true
        } catch (e) {
            return false
        }
    }

    // What is wrong with a rule, shown on it. `hard` ones keep it from being written (an invalid regex
    // would just match nothing, a bad colour would be ignored by the plugin): see writable().
    function problemList(r) {
        const out = []
        if (!hasMatch(r))
            out.push({ text: "Needs something to match", hard: true })
        for (const k of ["class", "title", "initial_class", "initial_title"]) {
            if (!validRegex(r.match[k]))
                out.push({ text: "The " + k.replace("_", " ") + " is not a valid regex", hard: true })
        }
        const t = r.glass.params.tint
        if (r.glass.mode === "custom" && t !== undefined && !/^#[0-9a-fA-F]{6}$/.test(t))
            out.push({ text: "The tint colour must be #rrggbb", hard: true })
        if (r.glass.mode === "inherit")
            out.push({ text: "No effect yet", hard: true })
        return out
    }

    function problems(r) {
        return problemList(r).map(p => p.text)
    }

    function writable(r) {
        return problemList(r).every(p => !p.hard)
    }

    // One line about what a rule matches.
    function matchSummary(r) {
        const m = r.match
        const parts = []
        if (m.class) parts.push("class " + m.class)
        if (m.title) parts.push("title " + m.title)
        if (m.initial_class) parts.push("initial class " + m.initial_class)
        if (m.initial_title) parts.push("initial title " + m.initial_title)
        if (m.float) parts.push(m.float === "yes" ? "floating" : "tiled")
        return parts.length ? parts.join(" · ") : "nothing yet"
    }

    // ---- writing and applying -------------------------------------------------------------------

    property var ownWrites: []

    function commit() {
        SettingsHistory.committed(root)
        writeTimer.restart()
    }

    Timer {
        id: writeTimer
        interval: 600
        onTriggered: root.writeNow()
    }

    function writeNow() {
        writtenLook = defaultLook
        const text = RuleLua.toLua(rules)
        ownWrites = ownWrites.concat([text]).slice(-8)
        status = "saving"
        message = ""
        file.setText(text)
    }

    function reloadNow() {
        if (reloadProc.running) {
            reloadAgain = true
            return
        }
        status = "reloading"
        reloadProc.running = true
    }

    property bool reloadAgain: false

    Process {
        id: reloadProc
        command: ["hyprctl", "reload"]
        stdout: StdioCollector { id: reloadOut }
        stderr: StdioCollector { id: reloadErr }
        onExited: (code, st) => {
            if (code !== 0) {
                root.status = "error"
                root.message = "hyprctl reload failed: " + (reloadErr.text.trim() || reloadOut.text.trim() || ("exit code " + code))
                return
            }
            // Hyprland reads the config a moment after it answers: look at the errors after that.
            errorTimer.restart()
        }
    }

    Timer {
        id: errorTimer
        interval: 800
        onTriggered: {
            errorProc.running = true
        }
    }

    Process {
        id: errorProc
        command: ["hyprctl", "configerrors"]
        stdout: StdioCollector { id: errorOut }
        onExited: (code, st) => {
            // Only the lines about this file (the base config may have its own).
            const base = root.path.replace(/^.*\//, "")
            const mine = errorOut.text.split("\n").filter(l => l.indexOf(base) >= 0 && !/^\s*\[C\]|stack traceback/.test(l))
            if (mine.length > 0) {
                root.status = "error"
                root.message = mine.map(l => l.replace(/^.*?hyprland-settings\.lua:/, "line ")).join("\n")
            } else {
                root.status = "ok"
                root.message = ""
            }
            if (root.reloadAgain) {
                root.reloadAgain = false
                root.reloadNow()
            }
        }
    }

    FileView {
        id: file
        path: root.path
        blockLoading: true
        watchChanges: true
        printErrors: false

        onSaved: root.reloadNow()
        onSaveFailed: error => {
            root.status = "error"
            root.message = "Could not write " + root.path + ": " + error
        }
        onFileChanged: reload()
        onLoaded: root.parseFile(text())
        Component.onCompleted: if (loaded) root.parseFile(text())
    }

    function parseFile(text) {
        if (ownWrites.indexOf(text) >= 0)
            return
        const data = RuleLua.fromLua(text)
        if (data !== null) {
            follow = data.follow
            writtenLook = data.look
            rules = data.rules
            SettingsHistory.rebase(root)
        }
    }

    Component.onCompleted: SettingsHistory.register(root, () => ({ rules: rules, follow: follow }), s => {
        rules = s.rules
        follow = s.follow
        commit()
    }, locate)

    // What differs between two states, as a key for HyprlandPage.scrollTo: a base rule that follows the
    // default look or not ("base:<name>"), else the first rule that was added, removed or changed
    // (<id>, or <id>#<field> for the field of its editor). A rule that no longer exists has nothing to
    // show: the page alone.
    function locate(from, to) {
        const page = key => ({ catId: "windowRules", key: key })
        const name = from.follow.concat(to.follow).find(n => from.follow.includes(n) !== to.follow.includes(n))
        if (name !== undefined)
            return page("base:" + name)
        for (const r of to.rules) {
            const old = from.rules.find(x => x.id === r.id)
            if (!old)
                return page(r.id)
            const field = changedField(old, r)
            if (field !== "")
                return page(r.id + (field === true ? "" : "#" + field))
        }
        return page("")
    }

    // The first field of a rule that differs: its editor's field id, true when it has none (the enable
    // switch, the glass mode: the card is outlined), "" when nothing differs.
    function changedField(a, b) {
        const diff = (x, y) => JSON.stringify(x) !== JSON.stringify(y)
        if (a.enabled !== b.enabled)
            return true
        if (a.name !== b.name)
            return "name"
        for (const k of Object.keys(b.match).concat(Object.keys(a.match)))
            if (a.match[k] !== b.match[k])
                return k === "float" ? true : "match." + k
        for (let i = 0; i < Math.max(a.effects.length, b.effects.length); i++)
            if (diff(a.effects[i], b.effects[i]))
                return b.effects[i] ? "effect." + i : true
        if (a.glass.mode !== b.glass.mode)
            return true
        for (const k of Object.keys(b.glass.params).concat(Object.keys(a.glass.params)))
            if (diff(a.glass.params[k], b.glass.params[k]))
                return "param." + k
        return ""
    }

    // The file does not exist until the first change; look for it (Quickshell cannot watch a missing one).
    Timer {
        running: !file.loaded
        interval: 3000
        repeat: true
        onTriggered: file.reload()
    }

    // ---- starting an override from a base config rule (BaseRules) -----------------------------

    // A new rule of ours that starts from a rule of the base config: the same match and glass.
    function overrideOf(b) {
        const m = b.match
        const base = {
            name: "Override: " + (b.name || m.class || m.title || m.initial_class || "rule"),
            match: {
                class: typeof m.class === "string" ? m.class : "",
                title: typeof m.title === "string" ? m.title : "",
                initial_class: typeof m.initial_class === "string" ? m.initial_class : "",
                initial_title: typeof m.initial_title === "string" ? m.initial_title : "",
                float: m.float === true ? "yes" : (m.float === false ? "no" : "")
            },
            effects: b.effects.filter(e => e.key !== "lucent_glass"),
            glass: b.glass ? JSON.parse(JSON.stringify(b.glass)) : { mode: "inherit", params: {} }
        }
        return addRule(base)
    }
}
