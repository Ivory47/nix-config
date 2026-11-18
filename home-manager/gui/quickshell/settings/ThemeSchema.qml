pragma Singleton

import QtQuick

// Every value of Theme.qml, in groups, as the settings app lists it: what the Theme page shows
// and what the search finds. One entry per value (`key` is the Theme property):
//   key, label, type ("color" | "number" | "bool"), kind ("int" | "real", numbers), min, max, step,
//   alpha (colours with transparency), note (small grey text), keywords (synonyms for the search).
// A section can have a `button` (an action of ThemePage, shown next to its title) and `groups`:
// collapsible sub-sections ({ id, title, note, items }), closed until opened, for the specific settings
// (ThemePage shows them with a count of the changed values; the search finds their settings anyway and
// the jump button opens the group).
QtObject {
    id: root

    // The look settings of one kind of glass (Theme.<prefix>Frost, ...: see ThemeDefaults.qml), in the
    // order the group shows them. `who` is only for the notes.
    function lookItems(prefix, who) {
        const look = ["glass", "blur", "frosted", "lens", "liquid", "style", "appearance"]
        const rim = look.concat(["bevel", "edge", "border", "refraction"])
        return [
            { key: prefix + "Frost", keywords: look.concat(["blurred", "sharp", "transparency"]), label: "Frost", type: "number", kind: "real", min: 0, max: 1, step: 0.05, note: "1: only the blurred picture. Lower: some sharp shows" },
            { key: prefix + "TintStrength", keywords: look.concat(["tint", "colour", "color", "background", "dark", "opaque", "opacity", "hide"]), label: "Tint", type: "number", kind: "real", min: 0, max: 1, step: 0.05, note: "How much background colour is mixed in" },
            { key: prefix + "Brightness", keywords: look.concat(["light", "dark", "lighten", "darken", "tone"]), label: "Brightness", type: "number", kind: "real", min: -0.5, max: 0.5, step: 0.01, note: "Added to what is behind" },
            { key: prefix + "Contrast", keywords: look.concat(["tone", "flat", "sharpen"]), label: "Contrast", type: "number", kind: "real", min: 0.5, max: 1.5, step: 0.01 },
            { key: prefix + "Saturation", keywords: look.concat(["colour", "color", "vivid", "grey", "gray", "tone"]), label: "Saturation", type: "number", kind: "real", min: 0, max: 2, step: 0.05, note: "0 is grey" },
            { key: prefix + "Bevel", keywords: rim.concat(["rim", "width", "curved"]), label: "Rim width", type: "number", kind: "real", min: 0, max: 40, step: 1, note: "The curved glass edge, in px. 0 is flat" },
            { key: prefix + "Thickness", keywords: rim.concat(["rim", "height", "depth", "lens"]), label: "Rim height", type: "number", kind: "real", min: 0, max: 2, step: 0.05, note: "How far the rim bends what is behind" },
            { key: prefix + "BevelProfile", keywords: rim.concat(["rim", "curve", "profile", "smooth", "shape"]), label: "Rim curve", type: "number", kind: "real", min: 2, max: 4, step: 0.5, note: "2 round, 3 smooth, 4 smoothest. Compositor glass" },
            { key: prefix + "Refraction", keywords: rim.concat(["bend", "lens", "distortion", "magnify"]), label: "Refraction", type: "number", kind: "real", min: 0, max: 4, step: 0.1, note: "How strongly the rim bends the background" },
            { key: prefix + "Ior", keywords: rim.concat(["index", "refraction", "ior", "bend", "lens"]), label: "Index of refraction", type: "number", kind: "real", min: 1, max: 3, step: 0.05, note: "Higher bends more. 1.45 is glass" },
            { key: prefix + "Dispersion", keywords: rim.concat(["fringe", "rainbow", "chromatic", "colour", "color"]), label: "Dispersion", type: "number", kind: "real", min: 0, max: 0.5, step: 0.01, note: "Coloured fringes along the rim" },
            { key: prefix + "Shine", keywords: rim.concat(["light", "highlight", "gloss", "reflection", "glow"]), label: "Shine", type: "number", kind: "real", min: 0, max: 2, step: 0.05, note: "Light that catches the rim" }
        ]
    }

    readonly property var sections: [
        { title: "Colors", items: [
            { key: "background", keywords: ["colour", "panel", "menu", "window", "base", "dark"], label: "Background", note: "Panels, menus and the glass tint", type: "color" },
            { key: "surface", keywords: ["colour", "card", "control", "fill"], label: "Surface", type: "color" },
            { key: "surfaceAlt", keywords: ["colour", "border", "outline", "highlight", "hover", "selection"], label: "Surface (alternative)", note: "Borders and highlights", type: "color" },
            { key: "text", keywords: ["colour", "foreground", "font colour", "white"], label: "Text", type: "color" },
            { key: "textSecondary", keywords: ["colour", "subtitle", "description"], label: "Text, secondary", type: "color" },
            { key: "textMuted", keywords: ["colour", "dim", "grey", "gray", "disabled", "placeholder"], label: "Text, muted", type: "color" },
            { key: "accent", keywords: ["colour", "highlight", "primary", "title"], label: "Accent", type: "color" },
            { key: "green", keywords: ["colour", "success", "ok", "charging"], label: "Green", type: "color" },
            { key: "orange", keywords: ["colour", "warning"], label: "Orange", type: "color" },
            { key: "red", keywords: ["colour", "error", "danger", "critical", "low battery"], label: "Red", type: "color" },
            { key: "shadowColor", keywords: ["colour", "drop shadow", "menu shadow"], label: "Shadow", type: "color", alpha: true }
        ]},
        { title: "Status bar", button: "restartBar", items: [
            { key: "statusBarHeight", keywords: ["bar", "panel height", "size", "taskbar", "top bar"], label: "Height", type: "number", kind: "int", min: 24, max: 120, note: "Needs a restart of the bar's glass to be exact" },
            { key: "barBorderColor", keywords: ["bar", "line", "outline", "edge", "colour"], label: "Border color", type: "color" },
            { key: "barBorderOpacity", keywords: ["bar", "line", "transparency", "alpha"], label: "Border opacity", type: "number", kind: "real", min: 0, max: 1 },
            { key: "barFillOpacity", keywords: ["bar", "transparency", "alpha", "translucent"], label: "Fill opacity", type: "number", kind: "real", min: 0, max: 1, note: "Only visible with the glass off" },
            { key: "osdIndicatorWidth", keywords: ["volume", "brightness", "popup", "on-screen display", "size"], label: "OSD width", type: "number", kind: "int", min: 60, max: 400, step: 10 }
        ]},
        { title: "Notifications", items: [
            { key: "notificationTimeout", keywords: ["notification", "notify", "popup", "toast", "timeout", "duration", "dismiss", "disappear", "how long"], label: "Show for", type: "number", kind: "real", min: 0, max: 60, step: 1, note: "Seconds. 0: until clicked away. Critical ones always stay" }
        ]},
        { title: "Glass", items: [
            { key: "glass", keywords: ["blur", "transparency", "liquid", "frosted", "capture", "effects", "acrylic"], label: "Live glass", type: "bool", note: "Off: no screen capture. May need a restart of the shells" },
            { key: "compositorGlass", keywords: ["blur", "lag", "latency", "lucent", "plugin", "hyprland", "compositor", "bar", "fast", "window"], label: "Compositor glass", type: "bool", note: "Drawn by the Lucent plugin, with no lag. Off, or without the plugin: blurred from screen captures" },
            { key: "glassBlurRadius", keywords: ["blur", "frosted", "strength", "sigma", "bar", "popup", "launcher", "window"], label: "Blur radius", type: "number", kind: "real", min: 0, max: 40, step: 1, note: "Bar, popups and windows" }
        ], groups: [
            // Collapsed groups: the specific settings. `id` is for the page (which one is open); the
            // title and note are what the header shows.
            { id: "panels", title: "Panels", note: "Launcher, clipboard, settings and wallpaper picker", items: [
                { key: "popupOpacity", keywords: ["alpha", "transparency", "transparent", "translucent", "opacity", "see through", "glass", "launcher", "clipboard", "popup", "widget", "menu"], label: "Opacity", type: "number", kind: "real", min: 0.2, max: 1, step: 0.05, note: "Launcher and clipboard. Lower shows the desktop through" }
            ].concat(root.lookItems("glassPanel", "panels")) },
            { id: "bar", title: "Status bar", note: "The glass of the bar", items: root.lookItems("glassBar", "the bar") },
            { id: "shadow", title: "Popup shadow", note: "Launcher, clipboard and settings overlay", items: [
                { key: "popupShadowOpacity", keywords: ["shadow", "drop shadow", "depth", "elevation", "launcher", "clipboard", "popup"], label: "Shadow", type: "number", kind: "real", min: 0, max: 0.6, step: 0.05, note: "0 is off" },
                { key: "popupShadowBlur", keywords: ["shadow", "soft", "spread", "size", "launcher", "clipboard"], label: "Softness", type: "number", kind: "real", min: 4, max: 60, step: 1, note: "How far the shadow fades out" },
                { key: "popupShadowOffset", keywords: ["shadow", "distance", "height", "elevation", "launcher", "clipboard"], label: "Drop", type: "number", kind: "real", min: 0, max: 30, step: 1, note: "How far it falls below the popup" }
            ] },
            { id: "veil", title: "Settings desktop blur", note: "The blurred desktop behind the settings overlay", items: [
                { key: "scrimBlurRadius", keywords: ["blur", "dim", "veil", "background", "strength", "desktop", "scrim"], label: "Desktop blur", type: "number", kind: "real", min: 0, max: 40, step: 0.5, note: "Also the blur of the settings panel itself" }
            ] },
            { id: "performance", title: "Blur performance", note: "What the blur costs", items: [
                { key: "blurMaxTaps", keywords: ["blur", "quality", "performance", "cost", "samples", "taps", "gpu", "fast", "cheap", "expensive"], label: "Blur quality", type: "number", kind: "int", min: 4, max: 48, step: 2, note: "Samples per side: lower is cheaper" },
                { key: "blurTapsFalloff", keywords: ["blur", "quality", "performance", "cost", "samples", "taps", "gpu", "strength", "scaling", "adaptive"], label: "Fewer samples for stronger blur", type: "number", kind: "real", min: 0, max: 1, step: 0.1, note: "0: always the same. 1: fewer as the blur grows" }
            ] }
        ]},
        { title: "Shape", items: [
            { key: "radiusSmall", keywords: ["rounding", "round", "corners", "border radius", "curve"], label: "Small radius", type: "number", kind: "int", min: 0, max: 30 },
            { key: "radiusMedium", keywords: ["rounding", "round", "corners", "border radius", "curve"], label: "Medium radius", type: "number", kind: "int", min: 0, max: 30 },
            { key: "radiusLarge", keywords: ["rounding", "round", "corners", "border radius", "curve", "panel"], label: "Large radius", type: "number", kind: "int", min: 0, max: 40 }
        ]},
        { title: "Spacing", items: [
            { key: "spacingSmall", keywords: ["gap", "padding", "margin", "space", "distance"], label: "Small", type: "number", kind: "int", min: 0, max: 40 },
            { key: "spacingMedium", keywords: ["gap", "padding", "margin", "space", "distance"], label: "Medium", type: "number", kind: "int", min: 0, max: 40 },
            { key: "spacingLarge", keywords: ["gap", "padding", "margin", "space", "distance"], label: "Large", type: "number", kind: "int", min: 0, max: 60 }
        ]},
        { title: "Typography", items: [
            { key: "textSmall", keywords: ["font", "size", "typography", "text size", "font size"], label: "Small text", type: "number", kind: "int", min: 8, max: 40 },
            { key: "textMedium", keywords: ["font", "size", "typography", "text size", "font size"], label: "Medium text", type: "number", kind: "int", min: 8, max: 40 },
            { key: "textLarge", keywords: ["font", "size", "typography", "text size", "font size", "heading", "title"], label: "Large text", type: "number", kind: "int", min: 8, max: 60 }
        ]}
    ]
}
