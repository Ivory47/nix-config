-- The window rules a config could make (check.sh feeds them to the snapshot code of hyprland.lua, then
-- to the settings app's reader, shell.qml next to this file). Plain data; keep one of each kind.
hl.window_rule({ name = "plain", match = { class = "^kitty$" }, float = true })
hl.window_rule({
    name = 'quote "x"',
    match = { title = "a\\b", float = true, xwayland = false },
    opacity = "1.0 override",
    size = { 100, 200 },
})
hl.window_rule({
    name = "glassy",
    match = { class = "^(kitty|HeadlessKitty)$" },
    lucent_glass = table.concat({ "radius=4", "tint=#102030", "thickness=10", "ior=1.45" }, " "),
})
hl.window_rule({ name = "glass-off", match = { class = "x" }, lucent_glass = "false" })
hl.window_rule({ match = { class = "noname" }, no_focus = true })
