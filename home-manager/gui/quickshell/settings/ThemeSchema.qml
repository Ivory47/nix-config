pragma Singleton

import QtQuick

// Every value of Theme.qml as the settings app lists it, in categories (the sidebar entries, each a
// ThemePage) made of sections: what the pages show and what the search finds. One entry per value
// (`key` is the Theme property):
//   key, label, type ("color" | "number" | "bool" | "choice"), kind ("int" | "real", numbers), min, max,
//   step, alpha (colours with transparency), options (choices: [{ id, label }]), note (small grey text),
//   keywords (synonyms for the search), showIf ({ key, is }: only shown while Theme[key] === is; a block can
//   have one too, for all its settings).
//
// A category: { id, group (the top-level heading in the sidebar: SettingsIndex.groups), name, icon,
// description, actions (ThemeActions ids, buttons in the page header), sections }. A section: { id, title, note, kind, ... } where `kind` says how it is drawn:
//   "list" (default)  `items`, then `blocks` ([{ title, items }]: small titled sub-lists)
//   "colors"          `blocks` of colours, as a grid of swatches with one editor under it (ColorGrid)
//   "table"           `items`, drawn as `rows` ([{ label, keys }]) by `columns` (titles) (SizeTable)
//   "collapsed"       `items` under a header that opens on click, closed at start (ThemeGroup)
// `flatten(section)` lists every setting of a section with its place (for the search and the counts).
QtObject {
    id: root

    // The look settings of one kind of glass (Theme.<prefix>Frost, ...: see ThemeDefaults.qml), in
    // three blocks, shown only while `showIf` holds (if given).
    function lookBlocks(prefix, showIf) {
        const look = ["glass", "blur", "frosted", "lens", "liquid", "style", "appearance"]
        const rim = look.concat(["bevel", "edge", "border", "refraction"])
        const tone = [
            { key: prefix + "Frost", keywords: look.concat(["blurred", "sharp", "transparency"]), label: "Frost", type: "number", kind: "real", min: 0, max: 1, step: 0.05, note: "1: only the blurred picture. Lower: some sharp shows" },
            { key: prefix + "TintStrength", keywords: look.concat(["tint", "colour", "color", "background", "dark", "opaque", "opacity", "hide"]), label: "Tint", type: "number", kind: "real", min: 0, max: 1, step: 0.05, note: "How much background colour is mixed in" },
            { key: prefix + "Brightness", keywords: look.concat(["light", "dark", "lighten", "darken", "tone"]), label: "Brightness", type: "number", kind: "real", min: -0.5, max: 0.5, step: 0.01, note: "Added to what is behind" },
            { key: prefix + "Contrast", keywords: look.concat(["tone", "flat", "sharpen"]), label: "Contrast", type: "number", kind: "real", min: 0.5, max: 1.5, step: 0.01 },
            { key: prefix + "Saturation", keywords: look.concat(["colour", "color", "vivid", "grey", "gray", "tone"]), label: "Saturation", type: "number", kind: "real", min: 0, max: 2, step: 0.05, note: "0 is grey" }
        ]
        // The bar glass also has a tint colour (the panels use Background).
        if (prefix === "glassBar")
            tone.splice(2, 0, { key: "glassBarTint", keywords: look.concat(["tint", "colour", "color", "bar", "background", "hue"]), label: "Tint colour", type: "color", note: "Follows Background until set" })
        const blocks = [
            { title: "Tone", items: tone },
            { title: "Rim", items: [
                { key: prefix + "Bevel", keywords: rim.concat(["rim", "width", "curved"]), label: "Width", type: "number", kind: "real", min: 0, max: 40, step: 1, note: "The curved glass edge, in px. 0 is flat" },
                { key: prefix + "Thickness", keywords: rim.concat(["rim", "height", "depth", "lens"]), label: "Height", type: "number", kind: "real", min: 0, max: 2, step: 0.05, note: "How far the rim bends what is behind" },
                { key: prefix + "BevelProfile", keywords: rim.concat(["rim", "curve", "profile", "smooth", "shape"]), label: "Curve", type: "number", kind: "real", min: 2, max: 4, step: 0.5, note: "2 round, 3 smooth, 4 smoothest. Compositor glass only" }
            ] },
            { title: "Light", items: [
                { key: prefix + "Refraction", keywords: rim.concat(["bend", "lens", "distortion", "magnify"]), label: "Refraction", type: "number", kind: "real", min: 0, max: 4, step: 0.1, note: "How strongly the rim bends the background" },
                { key: prefix + "Ior", keywords: rim.concat(["index", "refraction", "ior", "bend", "lens"]), label: "Index of refraction", type: "number", kind: "real", min: 1, max: 3, step: 0.05, note: "Higher bends more. 1.45 is glass" },
                { key: prefix + "Dispersion", keywords: rim.concat(["fringe", "rainbow", "chromatic", "colour", "color"]), label: "Dispersion", type: "number", kind: "real", min: 0, max: 0.5, step: 0.01, note: "Coloured fringes along the rim" },
                { key: prefix + "Shine", keywords: rim.concat(["light", "highlight", "gloss", "reflection", "glow"]), label: "Shine", type: "number", kind: "real", min: 0, max: 2, step: 0.05, note: "Light that catches the rim" }
            ] }
        ]
        if (showIf)
            for (const b of blocks)
                b.showIf = showIf
        return blocks
    }

    // The choice between the default look and an own one (Theme.glassPanelLook / glassBarLook).
    function lookChoice(key, who, note) {
        return { key: key, keywords: ["glass", "look", "default", "own", "follow", "inherit", "custom", who], label: "Look", type: "choice", options: [
            { id: "default", label: "Default look" }, { id: "own", label: "Own look" } ], note: note }
    }

    // Every setting of a section: [{ item, place, showIf }]. `place` is the block it is in under the
    // section title ("" or "Rim"), `showIf` the setting's or its block's condition (or null).
    function flatten(section) {
        const out = []
        for (const i of (section.items || []))
            out.push({ item: i, place: "", showIf: i.showIf || null })
        for (const b of (section.blocks || []))
            for (const i of b.items)
                out.push({ item: i, place: b.title || "", showIf: i.showIf || b.showIf || null })
        return out
    }

    readonly property var shadowKeywords: ["shadow", "drop shadow", "depth", "elevation"]

    readonly property var categories: [
        { id: "appearance", group: "theme", name: "Appearance", icon: "󰏘", description: "Colours and sizes used by every shell", sections: [
            { id: "colors", title: "Colors", kind: "colors", blocks: [
                { title: "Base", items: [
                    { key: "background", keywords: ["colour", "panel", "menu", "window", "base", "dark"], label: "Background", note: "Panels, menus and the glass tint", type: "color" },
                    { key: "surface", keywords: ["colour", "card", "control", "fill"], label: "Surface", note: "Cards and controls", type: "color" },
                    { key: "surfaceAlt", keywords: ["colour", "border", "outline", "highlight", "hover", "selection", "alternative"], label: "Surface, alt", note: "Borders and highlights", type: "color" }
                ] },
                { title: "Text", items: [
                    { key: "text", keywords: ["colour", "foreground", "font colour", "white"], label: "Text", type: "color" },
                    { key: "textSecondary", keywords: ["colour", "subtitle", "description"], label: "Text, secondary", type: "color" },
                    { key: "textMuted", keywords: ["colour", "dim", "grey", "gray", "disabled", "placeholder"], label: "Text, muted", type: "color" }
                ] },
                { title: "Accents", items: [
                    { key: "accent", keywords: ["colour", "highlight", "primary", "title"], label: "Accent", type: "color" },
                    { key: "green", keywords: ["colour", "success", "ok", "charging"], label: "Green", type: "color" },
                    { key: "orange", keywords: ["colour", "warning"], label: "Orange", type: "color" },
                    { key: "red", keywords: ["colour", "error", "danger", "critical", "low battery"], label: "Red", type: "color" },
                    { key: "shadowColor", keywords: ["colour", "drop shadow", "menu shadow"], label: "Shadow", type: "color", alpha: true }
                ] }
            ] },
            { id: "sizes", title: "Sizes", kind: "table", columns: ["Small", "Medium", "Large"], rows: [
                { label: "Corner radius", keys: ["radiusSmall", "radiusMedium", "radiusLarge"] },
                { label: "Spacing", keys: ["spacingSmall", "spacingMedium", "spacingLarge"] },
                { label: "Text size", keys: ["textSmall", "textMedium", "textLarge"] }
            ], items: [
                { key: "radiusSmall", keywords: ["rounding", "round", "corners", "border radius", "curve"], label: "Small radius", type: "number", kind: "int", min: 0, max: 30 },
                { key: "radiusMedium", keywords: ["rounding", "round", "corners", "border radius", "curve"], label: "Medium radius", type: "number", kind: "int", min: 0, max: 30 },
                { key: "radiusLarge", keywords: ["rounding", "round", "corners", "border radius", "curve", "panel"], label: "Large radius", type: "number", kind: "int", min: 0, max: 40 },
                { key: "spacingSmall", keywords: ["gap", "padding", "margin", "space", "distance"], label: "Small spacing", type: "number", kind: "int", min: 0, max: 40 },
                { key: "spacingMedium", keywords: ["gap", "padding", "margin", "space", "distance"], label: "Medium spacing", type: "number", kind: "int", min: 0, max: 40 },
                { key: "spacingLarge", keywords: ["gap", "padding", "margin", "space", "distance"], label: "Large spacing", type: "number", kind: "int", min: 0, max: 60 },
                { key: "textSmall", keywords: ["font", "size", "typography", "text size", "font size"], label: "Small text", type: "number", kind: "int", min: 8, max: 40 },
                { key: "textMedium", keywords: ["font", "size", "typography", "text size", "font size"], label: "Medium text", type: "number", kind: "int", min: 8, max: 40 },
                { key: "textLarge", keywords: ["font", "size", "typography", "text size", "font size", "heading", "title"], label: "Large text", type: "number", kind: "int", min: 8, max: 60 }
            ] }
        ] },

        { id: "bar", group: "theme", name: "Status bar", icon: "󰍹", description: "Layout and size of the bar. Height and glass changes apply after a restart", actions: ["restartBar"], sections: [
            { id: "style", title: "Style", items: [
                { key: "barLayout", keywords: ["bar", "layout", "style", "notch", "islands", "balanced", "classic", "notification", "history", "osd", "brightness"], label: "Layout", type: "choice", options: [
                    { id: "classic", label: "Classic" }, { id: "balanced", label: "Balanced" }, { id: "islands", label: "Islands" }, { id: "notch", label: "Notch" } ],
                    note: "Balanced: clock in the centre. Islands: three pills. Notch: one pill that grows" },
                { key: "barCentreStyle", showIf: { key: "barLayout", is: "balanced" }, keywords: ["bar", "clock", "date", "time", "balanced", "capsule", "stacked", "rule", "notification", "badge"], label: "Clock style", type: "choice", options: [
                    { id: "capsule", label: "Capsule" }, { id: "stacked", label: "Stacked" }, { id: "rule", label: "Rule" } ],
                    note: "Date and time in the middle. Balanced layout only" },
                { key: "barOsdStyle", showIf: { key: "barLayout", is: "balanced" }, keywords: ["bar", "brightness", "volume", "osd", "indicator", "slider", "balanced", "bubble", "simple", "popup", "dock", "morph"], label: "Indicator style", type: "choice", options: [
                    { id: "simple", label: "Simple" }, { id: "bubble", label: "Bubble" }, { id: "dock", label: "Dock" } ],
                    note: "How brightness and volume changes show. Balanced layout only" }
            ] },
            { id: "size", title: "Size", items: [
                { key: "statusBarHeight", keywords: ["bar", "panel height", "size", "taskbar", "top bar"], label: "Height", type: "number", kind: "int", min: 24, max: 120, note: "Restart the bar for the glass to fit exactly" },
                { key: "osdIndicatorWidth", keywords: ["volume", "brightness", "popup", "on-screen display", "size", "osd"], label: "OSD width", type: "number", kind: "int", min: 60, max: 400, step: 10, note: "The brightness and volume indicator" }
            ] },
            { id: "border", title: "Border & fill", items: [
                { key: "barBorderColor", keywords: ["bar", "line", "outline", "edge", "colour"], label: "Border color", type: "color" },
                { key: "barBorderOpacity", keywords: ["bar", "line", "transparency", "alpha"], label: "Border opacity", type: "number", kind: "real", min: 0, max: 1 },
                { key: "barFillOpacity", keywords: ["bar", "transparency", "alpha", "translucent"], label: "Fill opacity", type: "number", kind: "real", min: 0, max: 1, note: "Only visible with the glass off" }
            ] },
            { id: "glass", title: "Glass", items: [
                root.lookChoice("glassBarLook", "bar", "Default: the look set on the Glass page. Own: the settings below")
            ], blocks: root.lookBlocks("glassBar", { key: "glassBarLook", is: "own" }) }
        ] },

        { id: "panels", group: "theme", name: "Panels", icon: "󰕮", description: "Launcher, clipboard, settings and wallpaper picker", sections: [
            { id: "glass", title: "Glass", items: [
                root.lookChoice("glassPanelLook", "panel", "Default: the look set on the Glass page. Own: the settings below"),
                { key: "popupOpacity", keywords: ["alpha", "transparency", "transparent", "translucent", "opacity", "see through", "glass", "launcher", "clipboard", "popup", "widget", "menu", "panel"], label: "Opacity", type: "number", kind: "real", min: 0.2, max: 1, step: 0.05, note: "Launcher and clipboard. Lower shows the desktop through" }
            ], blocks: root.lookBlocks("glassPanel", { key: "glassPanelLook", is: "own" }) },
            { id: "overlay", title: "Settings overlay", items: [
                { key: "scrimDim", keywords: ["dim", "dark", "darker", "veil", "background", "desktop", "scrim", "settings", "backdrop", "overlay"], label: "Desktop dim", type: "number", kind: "real", min: 0, max: 0.9, step: 0.05, note: "How much darker the desktop gets behind the settings. 0: as it is" }
            ] },
            { id: "shadow", title: "Shadow", note: "Under the launcher, clipboard and settings overlay", items: [
                { key: "popupShadowOpacity", keywords: root.shadowKeywords.concat(["launcher", "clipboard", "popup"]), label: "Opacity", type: "number", kind: "real", min: 0, max: 0.6, step: 0.05, note: "0 is off" },
                { key: "popupShadowBlur", keywords: root.shadowKeywords.concat(["soft", "spread", "size", "launcher", "clipboard", "popup"]), label: "Softness", type: "number", kind: "real", min: 4, max: 60, step: 1, note: "How far the shadow fades out" },
                { key: "popupShadowOffset", keywords: root.shadowKeywords.concat(["distance", "height", "launcher", "clipboard", "popup"]), label: "Drop", type: "number", kind: "real", min: 0, max: 30, step: 1, note: "How far it falls below the popup" }
            ] }
        ] },

        { id: "notifications", group: "theme", name: "Notifications", icon: "󰂚", description: "Popups from apps and the notification centre", actions: ["testNotification"], sections: [
            { id: "popups", title: "Popups", items: [
                { key: "notificationTimeout", keywords: ["notification", "notify", "popup", "toast", "timeout", "duration", "dismiss", "disappear", "how long"], label: "Show for", type: "number", kind: "real", min: 0, max: 60, step: 1, note: "Seconds. 0: until clicked away. Critical ones always stay" }
            ] },
            { id: "shadow", title: "Shadow", note: "Under the cards and the notification centre", items: [
                { key: "notificationShadowOpacity", keywords: root.shadowKeywords.concat(["notification", "notification centre", "history", "popup", "card"]), label: "Opacity", type: "number", kind: "real", min: 0, max: 0.6, step: 0.05, note: "0 is off" },
                { key: "notificationShadowBlur", keywords: root.shadowKeywords.concat(["soft", "spread", "size", "notification", "notification centre"]), label: "Softness", type: "number", kind: "real", min: 4, max: 60, step: 1, note: "How far the shadow fades out" },
                { key: "notificationShadowOffset", keywords: root.shadowKeywords.concat(["distance", "height", "notification", "notification centre"]), label: "Drop", type: "number", kind: "real", min: 0, max: 30, step: 1, note: "How far it falls below the card" }
            ] }
        ] },

        { id: "glass", group: "theme", name: "Glass", icon: "󰂵", description: "Live glass and the default look. The panels and the status bar can follow it or have their own", sections: [
            { id: "general", title: "General", items: [
                { key: "glass", keywords: ["blur", "transparency", "liquid", "frosted", "capture", "effects", "acrylic"], label: "Live glass", type: "bool", note: "Off: no screen capture. May need a restart of the shells" },
                { key: "compositorGlass", keywords: ["blur", "lag", "latency", "lucent", "plugin", "hyprland", "compositor", "bar", "fast", "window"], label: "Compositor glass", type: "bool", note: "Drawn by the Lucent plugin, with no lag. Off or without the plugin: blurred from screen captures" },
                { key: "glassBlurRadius", keywords: ["blur", "frosted", "strength", "sigma", "bar", "popup", "launcher", "window", "settings", "overlay"], label: "Blur radius", type: "number", kind: "real", min: 0, max: 40, step: 1, note: "Bar, panels and windows" }
            ] },
            { id: "look", title: "Default look", note: "Used by the panels, and by the status bar and window rules that are set to follow it", blocks: root.lookBlocks("glassDefault") },
            { id: "performance", title: "Performance", note: "What the blur costs", kind: "collapsed", items: [
                { key: "blurMaxTaps", keywords: ["blur", "quality", "performance", "cost", "samples", "taps", "gpu", "fast", "cheap", "expensive"], label: "Blur quality", type: "number", kind: "int", min: 4, max: 48, step: 2, note: "Samples per side: lower is cheaper" },
                { key: "blurTapsFalloff", keywords: ["blur", "quality", "performance", "cost", "samples", "taps", "gpu", "strength", "scaling", "adaptive"], label: "Fewer samples for stronger blur", type: "number", kind: "real", min: 0, max: 1, step: 0.1, note: "0: always the same. 1: fewer as the blur grows" }
            ] }
        ] }
    ]
}
