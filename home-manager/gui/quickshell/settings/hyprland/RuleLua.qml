pragma Singleton

import QtQuick
import qs.core

// HyprlandStore's rules as the text of hyprland-settings.lua and back. `toLua(rules)` writes the Lua (the
// rules, and the same data as JSON in a comment); `fromLua(text)` reads that JSON again. Stateless: it
// reads what it needs (the follow list, the default look, the plugin path) from HyprlandStore.
QtObject {
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
            return HyprlandStore.withDefaultLook(r.glass.params)
        const parts = []
        for (const p of HyprlandStore.glassParams) {
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
        for (const e of r.effects || [])
            if (e.value.trim() !== "")
                lines.push("    " + e.key + " = " + e.value + ",")
        if (r.glass.mode !== "inherit")
            lines.push("    lucent_glass = " + luaStr(glassString(r)) + ",")
        lines.push("})")
        return lines.join("\n")
    }

    function toLua(list) {  // the rules (HyprlandStore.rules); the follow list and the look are the store's
        const out = []
        out.push("-- hyprland-settings.lua: written by the settings app (Hyprland › Window rules). Do not edit it")
        out.push("-- by hand: the app rewrites it at every change, and the rules below come from the data in the")
        out.push("-- comment. It is loaded at the END of hyprland.lua, so these rules override the base config's")
        out.push("-- (a later rule wins), and it is in .gitignore: it never goes to GitHub.")
        out.push("--[====[ quickshell-settings")
        out.push(JSON.stringify({ version: 1, rules: list, follow: HyprlandStore.follow, look: HyprlandStore.defaultLook }, null, 2))
        out.push("]====]")
        out.push("")
        out.push("-- lucent_glass is a window rule effect of the Lucent plugin: unknown (an error) without it.")
        out.push("local lucent = io.open(\"" + HyprlandStore.pluginPath + "\", \"r\")")
        out.push("if lucent then")
        out.push("    lucent:close()")
        out.push("")
        let n = 0
        // The base rules that follow the default look, first (the rules below win over them).
        out.push("    LucentGlassFollowers = LucentGlassFollowers or {}")
        for (const name of HyprlandStore.follow) {
            const b = BaseRules.rules.find(x => x.name === name)
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
            out.push("        lucent_glass = " + luaStr(HyprlandStore.withDefaultLook(b.glass.params)) + ",")
            out.push("    })")
            out.push("")
            n++
        }
        const used = {}
        // The first rule of the list is written last: a later rule wins, so the rule higher in the list
        // has the say when several match the same window.
        for (let i = list.length - 1; i >= 0; i--) {
            const r = list[i]
            if (!r.enabled || !HyprlandStore.writable(r))
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

    // The file's text -> { rules, follow, look }, or null when it has no data of ours.
    function fromLua(text) {
        const m = /--\[====\[ quickshell-settings\n([\s\S]*?)\n\]====\]/.exec(text)
        if (!m)
            return null
        try {
            const data = JSON.parse(m[1])
            if (!data || !Array.isArray(data.rules))
                return null
            // Fill in what an older or hand-made file may lack.
            const rules = data.rules.map(r => {
                const e = HyprlandStore.emptyRule()
                return {
                    id: typeof r.id === "string" && r.id ? r.id : e.id,
                    name: typeof r.name === "string" ? r.name : "",
                    enabled: r.enabled !== false,
                    match: Object.assign(e.match, r.match || {}),
                    effects: HyprlandStore.cleanEffects(r.effects),
                    glass: {
                        mode: HyprlandStore.modes.indexOf(r.glass?.mode) >= 0 ? r.glass.mode : "custom",
                        params: (r.glass && typeof r.glass.params === "object" && r.glass.params) ? r.glass.params : {}
                    }
                }
            })
            return {
                rules: rules,
                follow: Array.isArray(data.follow) ? data.follow.filter(x => typeof x === "string") : [],
                look: typeof data.look === "string" ? data.look : ""
            }
        } catch (e) {
            return null
        }
    }
}
