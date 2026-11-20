import QtQuick
import Quickshell
import qs.hyprland

// Reads the snapshot of the Hyprland config (HYPRLAND_CONFIG_FILE, written from rules.lua by check.sh) with
// the settings app's BaseRules and checks what came out. Prints "TEST PASS" or "TEST FAIL: <what>".
ShellRoot {
    id: test

    function check() {
        const r = BaseRules.rules
        const fails = []
        const eq = (what, got, want) => {
            if (JSON.stringify(got) !== JSON.stringify(want))
                fails.push(what + ": got " + JSON.stringify(got) + ", want " + JSON.stringify(want))
        }
        eq("rule count", r.length, 5)
        if (r.length === 5) {
            eq("names", r.map(x => x.name), ["plain", "quote \"x\"", "glassy", "glass-off", ""])
            eq("match strings", r[0].match, { class: "^kitty$" })
            eq("match types", r[1].match, { float: true, title: "a\\b", xwayland: false })
            eq("effects (Lua text)", r[0].effects, [{ key: "float", value: "true" }])
            eq("effects with a string and a table", r[1].effects,
                [{ key: "opacity", value: "\"1.0 override\"" }, { key: "size", value: "{ 100, 200 }" }])
            eq("no glass", r[0].glass, null)
            eq("custom glass, values as the config says (not clamped)", r[2].glass,
                { mode: "custom", params: { radius: 4, tint: "#102030", thickness: 10, ior: 1.45 } })
            eq("glass off", r[3].glass, { mode: "off", params: {} })
            eq("a rule without a name", r[4].effects, [{ key: "no_focus", value: "true" }])
        }
        console.log(fails.length === 0 ? "TEST PASS" : "TEST FAIL: " + fails.join("; "))
        Qt.exit(fails.length === 0 ? 0 : 1)
    }

    // The file is read a moment after the singleton exists.
    Connections {
        target: BaseRules
        function onRulesChanged() { if (BaseRules.rules.length > 0) test.check() }
    }
    Timer {
        interval: 5000
        running: true
        onTriggered: test.check()
    }
}
