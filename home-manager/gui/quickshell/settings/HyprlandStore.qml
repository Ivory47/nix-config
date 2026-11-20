pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.shared

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
    readonly property string basePath: Quickshell.env("HYPRLAND_BASE_FILE") || (home + "/.config/hypr/hyprland.lua")
    // Where the plugin is installed: without it `lucent_glass` is an unknown key (a config error).
    readonly property string pluginPath: "/etc/hypr/plugins/liblucent.so"

    property var rules: []
    readonly property var modes: ["inherit", "default", "custom", "off"]

    // ---- the default look -----------------------------------------------------------------------

    // The lucent_glass keys a rule keeps for itself when it follows the default look (the rest are
    // the look).
    readonly property var ownKeys: ["radius", "taps", "corner_radius", "opacity"]

    // The default look (the settings app's Glass page) as lucent_glass parameters.
    readonly property var defaultLookParams: ({
        frost: Theme.glassDefault.frost,
        tint: ThemeStore.colorString(Theme.background, false),
        tint_strength: Theme.glassDefault.tintStrength,
        brightness: Theme.glassDefault.brightness,
        contrast: Theme.glassDefault.contrast,
        saturation: Theme.glassDefault.saturation,
        bevel: Theme.glassDefault.bevel,
        thickness: Theme.glassDefault.thickness,
        bevel_profile: Theme.glassDefault.bevelProfile,
        refraction: Theme.glassDefault.refraction,
        ior: Theme.glassDefault.ior,
        dispersion: Theme.glassDefault.dispersion,
        shine: Theme.glassDefault.shine
    })
    readonly property string defaultLook: glassParams
        .filter(p => defaultLookParams[p.key] !== undefined)
        .map(p => p.key + "=" + (p.type === "color" ? defaultLookParams[p.key] : num(defaultLookParams[p.key])))
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
                parts.push(p.key + "=" + num(params[p.key]))
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
    readonly property var glassParams: [
        { block: "Blur", key: "radius", label: "Radius", min: 0, max: 100, step: 1, def: 16, note: "Blur strength, in pixels" },
        { block: "Blur", key: "taps", label: "Quality", min: 1, max: 48, step: 1, def: 32, note: "Samples per side: lower is cheaper" },
        { block: "Tone", key: "frost", label: "Frost", min: 0, max: 1, step: 0.05, def: 1, note: "1: only the blurred picture. Lower: some sharp shows" },
        { block: "Tone", key: "tint", label: "Tint colour", type: "color", def: "#000000", note: "Mixed in with the tint strength" },
        { block: "Tone", key: "tint_strength", label: "Tint strength", min: 0, max: 1, step: 0.05, def: 0, note: "0: no tint (with a tint colour alone: 0.25)" },
        { block: "Tone", key: "brightness", label: "Brightness", min: -1, max: 1, step: 0.01, def: 0, note: "Added to what is behind" },
        { block: "Tone", key: "contrast", label: "Contrast", min: 0, max: 3, step: 0.01, def: 1 },
        { block: "Tone", key: "saturation", label: "Saturation", min: 0, max: 3, step: 0.05, def: 1, note: "0 is grey" },
        { block: "Rim", key: "bevel", label: "Width", min: 0, max: 40, step: 1, def: 0, note: "The curved glass edge, in px. 0 is flat" },
        { block: "Rim", key: "thickness", label: "Height", min: 0, max: 16, step: 0.1, def: 0, note: "How far the rim bends what is behind" },
        { block: "Rim", key: "bevel_profile", label: "Curve", min: 2, max: 4, step: 0.5, def: 3, note: "2 round, 3 smooth, 4 smoothest" },
        { block: "Light", key: "refraction", label: "Refraction", min: 0, max: 16, step: 0.1, def: 0, note: "Needs a rim width and height" },
        { block: "Light", key: "ior", label: "Index of refraction", min: 1, max: 4, step: 0.05, def: 1.45, note: "Higher bends more" },
        { block: "Light", key: "dispersion", label: "Dispersion", min: 0, max: 1, step: 0.01, def: 0, note: "Coloured fringes along the rim" },
        { block: "Light", key: "shine", label: "Shine", min: 0, max: 8, step: 0.1, def: 0, note: "Light that catches the rim" },
        { block: "Window", key: "corner_radius", label: "Corner radius", min: 0, max: 40, step: 1, def: 6, note: "Left out: the window's own rounding (6)" },
        { block: "Window", key: "opacity", label: "Opacity", min: 0, max: 1, step: 0.05, def: 1, note: "Below 1 the sharp background shows through" }
    ]

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
            glass: { mode: "custom", params: {} }
        }
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

    // ---- Lua ------------------------------------------------------------------------------------

    function luaStr(s) {
        return "\"" + String(s).replace(/[\u0000-\u001f]/g, "").replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + "\""
    }

    function num(v) {
        return String(Number(Number(v).toFixed(4)))
    }

    function glassString(r) {
        if (r.glass.mode === "off")
            return "false"
        if (r.glass.mode === "default")
            return withDefaultLook(r.glass.params)
        const parts = []
        for (const p of glassParams) {
            const v = r.glass.params[p.key]
            if (v === undefined)
                continue
            parts.push(p.key + "=" + (p.type === "color" ? v : num(v)))
        }
        return parts.length > 0 ? parts.join(" ") : "true"
    }

    function ruleLua(r, name) {
        const m = r.match
        const match = []
        for (const k of ["class", "title", "initial_class", "initial_title"])
            if (m[k])
                match.push(k + " = " + luaStr(m[k]))
        if (m.float)
            match.push("float = " + (m.float === "yes" ? "true" : "false"))
        const lines = ["hl.window_rule({"]
        if (name)
            lines.push("    name         = " + luaStr(name) + ",")
        lines.push("    match        = { " + match.join(", ") + " },")
        lines.push("    lucent_glass = " + luaStr(glassString(r)) + ",")
        lines.push("})")
        return lines.join("\n")
    }

    function toLua(list) {
        const out = []
        out.push("-- hyprland-settings.lua: written by the settings app (Hyprland › Window rules). Do not edit it")
        out.push("-- by hand: the app rewrites it at every change, and the rules below come from the data in the")
        out.push("-- comment. It is loaded at the END of hyprland.lua, so these rules override the base config's")
        out.push("-- (a later rule wins), and it is in .gitignore: it never goes to GitHub.")
        out.push("--[====[ quickshell-settings")
        out.push(JSON.stringify({ version: 1, rules: list, follow: follow, look: defaultLook }, null, 2))
        out.push("]====]")
        out.push("")
        out.push("-- lucent_glass is a window rule effect of the Lucent plugin: unknown (an error) without it.")
        out.push("local lucent = io.open(\"" + pluginPath + "\", \"r\")")
        out.push("if lucent then")
        out.push("    lucent:close()")
        out.push("")
        let n = 0
        // The base rules that follow the default look, first (the rules below win over them).
        out.push("    LucentGlassFollowers = LucentGlassFollowers or {}")
        for (const name of follow) {
            const b = baseRules.find(x => x.name === name)
            if (!b || !b.glass || b.glass.mode !== "custom")
                continue
            const match = []
            for (const k of Object.keys(b.match)) {
                const v = b.match[k]
                match.push(k + " = " + (typeof v === "string" ? luaStr(v) : typeof v === "boolean" ? String(v) : num(v)))
            }
            out.push("    LucentGlassFollowers[" + luaStr(name) + "] = hl.window_rule({")
            out.push("        name         = " + luaStr(name + " (default look)") + ",")
            out.push("        match        = { " + match.join(", ") + " },")
            out.push("        lucent_glass = " + luaStr(withDefaultLook(b.glass.params)) + ",")
            out.push("    })")
            out.push("")
            n++
        }
        const used = {}
        // The first rule of the list is written last: a later rule wins, so the rule higher in the list
        // has the say when several match the same window.
        for (let i = list.length - 1; i >= 0; i--) {
            const r = list[i]
            if (!r.enabled || !writable(r))
                continue
            let name = r.name.replace(/[^\w .\-]/g, "").trim()
            if (name) {
                let unique = name
                for (let i = 2; used[unique]; i++)
                    unique = name + " " + i
                used[unique] = true
                name = unique
            }
            out.push(ruleLua(r, name).replace(/^/gm, "    "))
            out.push("")
            n++
        }
        if (n === 0)
            out.push("    -- (no rules)")
        out.push("end")
        out.push("")
        return out.join("\n")
    }

    function fromLua(text) {
        const m = /--\[====\[ quickshell-settings\n([\s\S]*?)\n\]====\]/.exec(text)
        if (!m)
            return null
        try {
            const data = JSON.parse(m[1])
            if (!data || !Array.isArray(data.rules))
                return null
            root.follow = Array.isArray(data.follow) ? data.follow.filter(x => typeof x === "string") : []
            root.writtenLook = typeof data.look === "string" ? data.look : ""
            // Fill in what an older or hand-made file may lack.
            return data.rules.map(r => {
                const e = emptyRule()
                return {
                    id: typeof r.id === "string" && r.id ? r.id : e.id,
                    name: typeof r.name === "string" ? r.name : "",
                    enabled: r.enabled !== false,
                    match: Object.assign(e.match, r.match || {}),
                    glass: {
                        mode: root.modes.indexOf(r.glass?.mode) >= 0 ? r.glass.mode : "custom",
                        params: (r.glass && typeof r.glass.params === "object" && r.glass.params) ? r.glass.params : {}
                    }
                }
            })
        } catch (e) {
            return null
        }
    }

    // ---- writing and applying -------------------------------------------------------------------

    property var ownWrites: []

    function commit() {
        writeTimer.restart()
    }

    Timer {
        id: writeTimer
        interval: 600
        onTriggered: root.writeNow()
    }

    function writeNow() {
        writtenLook = defaultLook
        const text = toLua(rules)
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
        const list = fromLua(text)
        if (list !== null)
            rules = list
    }

    // The file does not exist until the first change; look for it (Quickshell cannot watch a missing one).
    Timer {
        running: !file.loaded
        interval: 3000
        repeat: true
        onTriggered: file.reload()
    }

    // ---- the base config's rules (read-only) ----------------------------------------------------

    property var baseRules: []

    // Removes Lua comments (and nothing else; strings are kept as they are).
    function stripComments(src) {
        let out = ""
        let i = 0
        const n = src.length
        while (i < n) {
            const c = src[i]
            if (c === "-" && src[i + 1] === "-") {
                const m = /^--\[(=*)\[/.exec(src.substr(i, 40))
                if (m) {
                    const close = "]" + m[1] + "]"
                    const e = src.indexOf(close, i + m[0].length)
                    i = e < 0 ? n : e + close.length
                } else {
                    const e = src.indexOf("\n", i)
                    i = e < 0 ? n : e
                }
                continue
            }
            if (c === "\"" || c === "'") {
                let j = i + 1
                while (j < n && src[j] !== c) {
                    if (src[j] === "\\")
                        j++
                    j++
                }
                out += src.substring(i, j + 1)
                i = j + 1
                continue
            }
            const lm = c === "[" ? /^\[(=*)\[/.exec(src.substr(i, 12)) : null
            if (lm) {
                const close = "]" + lm[1] + "]"
                const e = src.indexOf(close, i + lm[0].length)
                const stop = e < 0 ? n : e + close.length
                out += src.substring(i, stop)
                i = stop
                continue
            }
            out += c
            i++
        }
        return out
    }

    // The index of the bracket that closes the one at `open` ({ or ( ), or -1.
    function closeOf(src, open) {
        const pairs = { "{": "}", "(": ")", "[": "]" }
        let depth = 0
        const n = src.length
        for (let i = open; i < n; i++) {
            const c = src[i]
            if (c === "\"" || c === "'") {
                i++
                while (i < n && src[i] !== c) {
                    if (src[i] === "\\")
                        i++
                    i++
                }
                continue
            }
            const lm = c === "[" ? /^\[(=*)\[/.exec(src.substr(i, 12)) : null
            if (lm) {
                const e = src.indexOf("]" + lm[1] + "]", i + lm[0].length)
                if (e < 0)
                    return -1
                i = e + lm[1].length + 1
                continue
            }
            if (c === "{" || c === "(" || c === "[")
                depth++
            else if (c === "}" || c === ")" || c === "]") {
                depth--
                if (depth === 0)
                    return i
            }
        }
        return -1
    }

    // The fields `key = value` at the top level of a table body, as [{key, value}] (value as text).
    function topFields(body) {
        const parts = []
        let depth = 0
        let start = 0
        const n = body.length
        for (let i = 0; i < n; i++) {
            const c = body[i]
            if (c === "\"" || c === "'") {
                i++
                while (i < n && body[i] !== c) {
                    if (body[i] === "\\")
                        i++
                    i++
                }
                continue
            }
            const lm = c === "[" ? /^\[(=*)\[/.exec(body.substr(i, 12)) : null
            if (lm) {
                const e = body.indexOf("]" + lm[1] + "]", i + lm[0].length)
                if (e < 0)
                    break
                i = e + lm[1].length + 1
                continue
            }
            if (c === "{" || c === "(" || c === "[")
                depth++
            else if (c === "}" || c === ")" || c === "]")
                depth--
            else if (c === "," && depth === 0) {
                parts.push(body.substring(start, i))
                start = i + 1
            }
        }
        parts.push(body.substring(start))
        const out = []
        for (const p of parts) {
            const m = /^\s*([A-Za-z_]\w*)\s*=\s*([\s\S]*?)\s*$/.exec(p)
            if (m)
                out.push({ key: m[1], value: m[2] })
        }
        return out
    }

    // A Lua literal as text -> string / boolean, or undefined.
    function literal(v) {
        let m = /^"((?:[^"\\]|\\.)*)"$/.exec(v) || /^'((?:[^'\\]|\\.)*)'$/.exec(v)
        if (m)
            return m[1].replace(/\\(.)/g, "$1")
        m = /^\[(=*)\[([\s\S]*)\]\1\]$/.exec(v)
        if (m)
            return m[2]
        if (v === "true")
            return true
        if (v === "false")
            return false
        return undefined
    }

    // The rules of a Lua text: [{ name, match: {key: value}, effects: [{key, value}], glass }]
    function parseBaseRules(text) {
        const src = stripComments(text)
        const out = []
        let pos = 0
        while (true) {
            const at = src.indexOf("hl.window_rule(", pos)
            if (at < 0)
                break
            pos = at + 15
            const open = src.indexOf("{", at)
            if (open < 0)
                break
            const close = closeOf(src, open)
            if (close < 0)
                break
            pos = close
            const fields = topFields(src.substring(open + 1, close))
            const rule = { name: "", match: {}, effects: [], glass: null }
            for (const f of fields) {
                if (f.key === "name") {
                    rule.name = String(literal(f.value) ?? "")
                } else if (f.key === "match") {
                    const mo = f.value.indexOf("{")
                    const mc = mo >= 0 ? closeOf(f.value, mo) : -1
                    if (mc > 0)
                        for (const mf of topFields(f.value.substring(mo + 1, mc))) {
                            const lv = literal(mf.value)
                            if (lv !== undefined)
                                rule.match[mf.key] = lv
                        }
                } else if (f.key !== "enabled") {
                    rule.effects.push({ key: f.key, value: f.value.replace(/\s+/g, " ") })
                    if (f.key === "lucent_glass")
                        rule.glass = parseGlassValue(f.value)
                }
            }
            out.push(rule)
        }
        return out
    }

    // The value of a lucent_glass effect (a string, or table.concat of strings): -> { mode, params }.
    function parseGlassValue(value) {
        const strings = []
        const re = /"((?:[^"\\]|\\.)*)"/g
        let m
        while ((m = re.exec(value)) !== null)
            strings.push(m[1])
        const tokens = strings.join(" ").split(/[\s,]+/).filter(t => t.length > 0)
        if (tokens.length === 1 && /^(false|off|no|0)$/.test(tokens[0]))
            return { mode: "off", params: {} }
        const params = {}
        for (const t of tokens) {
            const kv = /^([a-z_]+)=(.+)$/.exec(t)
            if (!kv)
                continue
            const spec = glassParams.find(p => p.key === kv[1])
            if (!spec)
                continue
            if (spec.type === "color") {
                if (/^#[0-9a-fA-F]{6}$/.test(kv[2]))
                    params[spec.key] = kv[2].toLowerCase()
            } else {
                const v = parseFloat(kv[2])
                if (isFinite(v))
                    params[spec.key] = Math.max(spec.min, Math.min(spec.max, v))
            }
        }
        return { mode: "custom", params: params }
    }

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
            glass: b.glass ? JSON.parse(JSON.stringify(b.glass)) : { mode: "custom", params: {} }
        }
        return addRule(base)
    }

    // Read again when it changes (`hms` links a new one) and when the Window rules page is shown, so
    // that a rule written into hyprland.lua by hand shows up.
    function reloadBase() {
        baseFile.reload()
    }

    FileView {
        id: baseFile
        path: root.basePath
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.baseRules = root.parseBaseRules(text())
        Component.onCompleted: if (loaded) root.baseRules = root.parseBaseRules(text())
    }
}
