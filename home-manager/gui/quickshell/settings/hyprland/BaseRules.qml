pragma Singleton

import QtQuick
import Quickshell
import qs.shared

// The Window rules page's read-only list: the window rules of the base config (hyprland.lua). Hyprland's
// Lua API cannot list rules, so hyprland.lua records every hl.window_rule it makes and writes the record
// as JSON, `{ version, windowRules: [...] }`, to $XDG_RUNTIME_DIR/hyprland-config.json at every load or
// reload (a snapshot of what that file says, without the settings app's own rules; this app only reads
// it). `rules` is [{ name, match: {key: value}, effects: [{key, value: Lua text}], glass }]; `glass` is
// null, or { mode, params } read from the rule's lucent_glass.
Singleton {
    id: root

    // (The environment variable is for tests, to keep them away from the real file.)
    readonly property string path: Quickshell.env("HYPRLAND_CONFIG_FILE")
        || ((Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/hyprland-config.json")

    property var rules: []

    // Read again when the Window rules page is shown (the file is also watched).
    function reload() {
        file.reload()
    }

    JsonFile {
        id: file
        path: root.path
        onParsed: value => {
            // (A list read by JsonFile is a Qt sequence, not a JS array: round-trip it through JSON.)
            const data = JSON.parse(JSON.stringify(value ?? {}))
            const list = Array.isArray(data.windowRules) ? data.windowRules : []
            root.rules = list.map(r => {
                const effects = Array.isArray(r.effects) ? r.effects.map(e => ({ key: String(e.key), value: String(e.value) })) : []
                return {
                    name: typeof r.name === "string" ? r.name : "",
                    match: r.match && typeof r.match === "object" ? r.match : {},
                    effects: effects,
                    glass: typeof r.glass === "string" ? root.parseGlassValue(r.glass) : null
                }
            })
        }
        onMissing: root.rules = []
    }

    // The value of a lucent_glass effect ("radius=4 tint=#000000 ..."): -> { mode, params }.
    function parseGlassValue(value) {
        const tokens = String(value).split(/[\s,]+/).filter(t => t.length > 0)
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
                    params[spec.key] = v  // as the config says: not clamped to the sliders' range
            }
        }
        return { mode: "custom", params: params }
    }
}
