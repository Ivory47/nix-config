pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The Window rules page's read-only list: the rules of the base config (hyprland.lua), read from its text
// (a small Lua reader for `hl.window_rule({ ... })`, only to show the rules and to start an override from
// one: HyprlandStore.overrideOf). `rules` is [{ name, match: {key: value}, effects: [{key, value}], glass }],
// `glass` is null, or { mode, params } read from the rule's lucent_glass.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""
    // (The environment variable is for tests, to keep them away from the real file.)
    readonly property string path: Quickshell.env("HYPRLAND_BASE_FILE") || (home + "/.config/hypr/hyprland.lua")

    property var rules: []

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
    function parse(text) {
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
            const spec = HyprlandStore.glassParams.find(p => p.key === kv[1])
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

    // Read again when it changes (`hms` links a new one) and when the Window rules page is shown, so
    // that a rule written into hyprland.lua by hand shows up.
    function reload() {
        file.reload()
    }

    FileView {
        id: file
        path: root.path
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.rules = root.parse(text())
        Component.onCompleted: if (loaded) root.rules = root.parse(text())
    }
}
