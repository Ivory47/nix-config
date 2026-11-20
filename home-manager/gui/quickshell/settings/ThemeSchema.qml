pragma Singleton

import QtQuick

// Every value of Theme.qml as the settings app lists it, in categories (the sidebar entries, each a
// ThemePage) made of sections: what the pages show and what the search finds. One entry per value
// (`key` is the Theme property):
//   key (the Theme value, or a path into a group: "glassBar.frost"; Theme.value(key) reads it), label, type ("color" | "number" | "bool" | "choice"), kind ("int" | "real", numbers), min, max,
//   step, alpha (colours with transparency), options (choices: [{ id, label }]), note (small grey text),
//   keywords (synonyms for the search), showIf ({ key, is }: only shown while Theme.value(key) === is; a block can
//   have one too, for all its settings).
//
// A category: { id, group (the top-level heading in the sidebar: SettingsIndex.groups), name, icon,
// description, actions (ThemeActions ids, buttons in the page header), sections }. A section: { id, title, note, kind, ... } where `kind` says how it is drawn:
//   "list" (default)  `items`, then `blocks` ([{ title, items }]: small titled sub-lists)
//   "colors"          `blocks` of colours, as a grid of swatches with one editor under it (ColorGrid)
//   "table"           `items`, drawn as `rows` ([{ label, keys }]) by `columns` (titles) (SizeTable)
//   "collapsed"       `items` under a header that opens on click, closed at start (ThemeGroup)
//   "widgets"         `widgets` ([{ id, title, note, items, blocks }], made by `widget()`): one line each with
//                     the Default look / Own look choice; Own opens its look in place (GlassWidgetRow)
// An item of type "link" (`look`: a widget's GlassLook name) is a row that says whether that widget follows
// the default look and jumps to it (LinkField); it is not a Theme value, so `flatten` leaves it out.
// `flatten(section)` lists every setting of a section with its place (for the search and the counts).
QtObject {
    id: root

    // The look settings of one kind of glass (Theme.<prefix>.frost, ...: a GlassLook, see ThemeDefaults.qml), in
    // three blocks, shown only while `showIf` holds (if given).
    function lookBlocks(prefix, showIf) {
        const look = ["glass", "blur", "frosted", "lens", "liquid", "style", "appearance"]
        const rim = look.concat(["bevel", "edge", "border", "refraction"])
        const tone = [
            { key: prefix + ".frost", keywords: look.concat(["blurred", "sharp", "transparency"]), label: "Frost", type: "number", kind: "real", min: 0, max: 1, step: 0.05, note: "1: only the blurred picture. Lower: some sharp shows" },
            { key: prefix + ".tintStrength", keywords: look.concat(["tint", "colour", "color", "background", "dark", "opaque", "opacity", "hide"]), label: "Tint", type: "number", kind: "real", min: 0, max: 1, step: 0.05, note: "How much background colour is mixed in" },
            { key: prefix + ".brightness", keywords: look.concat(["light", "dark", "lighten", "darken", "tone"]), label: "Brightness", type: "number", kind: "real", min: -0.5, max: 0.5, step: 0.01, note: "Added to what is behind" },
            { key: prefix + ".contrast", keywords: look.concat(["tone", "flat", "sharpen"]), label: "Contrast", type: "number", kind: "real", min: 0.5, max: 1.5, step: 0.01 },
            { key: prefix + ".saturation", keywords: look.concat(["colour", "color", "vivid", "grey", "gray", "tone"]), label: "Saturation", type: "number", kind: "real", min: 0, max: 2, step: 0.05, note: "0 is grey" }
        ]
        // The tint colour: Background for the default look until set, the default look's for a widget.
        tone.splice(2, 0, { key: prefix + ".tint", keywords: look.concat(["tint", "colour", "color", "background", "hue"]), label: "Tint colour", type: "color",
            note: prefix === "glassDefault" ? "Follows Background until set" : "The default look's until set" })
        // The blur: the default look's is the setting glassBlurRadius, a widget's its own key.
        const blur = { key: prefix === "glassDefault" ? "glassBlurRadius" : prefix + ".blurRadius",
            keywords: look.concat(["strength", "sigma", "radius", "amount"]), label: "Blur radius", type: "number", kind: "real",
            min: 0, max: 40, step: 1, note: "How strongly what is behind is blurred" }
        const blocks = [
            { title: "Blur", items: [ blur ] },
            { title: "Tone", items: tone },
            { title: "Rim", items: [
                { key: prefix + ".bevel", keywords: rim.concat(["rim", "width", "curved"]), label: "Width", type: "number", kind: "real", min: 0, max: 40, step: 1, note: "The curved glass edge, in px. 0 is flat" },
                { key: prefix + ".thickness", keywords: rim.concat(["rim", "height", "depth", "lens"]), label: "Height", type: "number", kind: "real", min: 0, max: 2, step: 0.05, note: "How far the rim bends what is behind" },
                { key: prefix + ".bevelProfile", keywords: rim.concat(["rim", "curve", "profile", "smooth", "shape"]), label: "Curve", type: "number", kind: "real", min: 2, max: 4, step: 0.5, note: "2 round, 3 smooth, 4 smoothest. Compositor glass only" }
            ] },
            { title: "Light", items: [
                { key: prefix + ".refraction", keywords: rim.concat(["bend", "lens", "distortion", "magnify"]), label: "Refraction", type: "number", kind: "real", min: 0, max: 4, step: 0.1, note: "How strongly the rim bends the background" },
                { key: prefix + ".ior", keywords: rim.concat(["index", "refraction", "ior", "bend", "lens"]), label: "Index of refraction", type: "number", kind: "real", min: 1, max: 3, step: 0.05, note: "Higher bends more. 1.45 is glass" },
                { key: prefix + ".dispersion", keywords: rim.concat(["fringe", "rainbow", "chromatic", "colour", "color"]), label: "Dispersion", type: "number", kind: "real", min: 0, max: 0.5, step: 0.01, note: "Coloured fringes along the rim" },
                { key: prefix + ".shine", keywords: rim.concat(["light", "highlight", "gloss", "reflection", "glow"]), label: "Shine", type: "number", kind: "real", min: 0, max: 2, step: 0.05, note: "Light that catches the rim" }
            ] }
        ]
        for (const b of blocks) {
            if (showIf)
                b.showIf = showIf
            // A widget's own look: a value it does not set follows the default look (shown dimmed).
            if (prefix !== "glassDefault")
                for (const i of b.items)
                    i.inherits = true
        }
        return blocks
    }

    // One widget (or group of widgets) of the Glass page's "widgets" section: its choice between the
    // default look and its own (`<name>.look`), and its own look, shown only while that is "own".
    // `name` is its GlassLook in Theme ("glassLauncher"); `words` extra search words.
    // `only` (optional): the titles of the blocks that apply to it (a widget that uses only the blur).
    function widget(name, title, note, words, only) {
        const own = { key: name + ".look", is: "own" }
        return {
            id: name, title: title, note: note,
            items: [ { key: name + ".look", keywords: ["glass", "look", "default", "own", "follow", "custom", "widget"].concat(words),
                label: title, type: "choice", note: note, options: [ { id: "default", label: "Default look" }, { id: "own", label: "Own look" } ] } ],
            blocks: lookBlocks(name, own).filter(b => !only || only.indexOf(b.title) >= 0)
        }
    }

    // A row on a widget's own page that leads to its glass on the Glass page (LinkField).
    function glassLink(name, label) {
        return { type: "link", look: name, label: label, keywords: [] }
    }

    // Every setting of a section: [{ item, place, showIf, group }]. `place` is where it is under the section
    // title ("", "Rim", "App launcher › Rim"), `showIf` the setting's or its block's condition (or null),
    // `group` the widget whose look it is in (it opens and closes; "" otherwise).
    function flatten(section) {
        const out = []
        for (const i of (section.items || []))
            if (i.type !== "link")
                out.push({ item: i, place: "", showIf: i.showIf || null, group: "" })
        for (const b of (section.blocks || []))
            for (const i of b.items)
                out.push({ item: i, place: b.title || "", showIf: i.showIf || b.showIf || null, group: "" })
        // A widget: its choice (always shown), then its look (only while own; it opens and closes).
        for (const w of (section.widgets || [])) {
            for (const i of w.items)
                out.push({ item: i, place: w.title, showIf: null, group: "" })
            for (const b of w.blocks)
                for (const i of b.items)
                    out.push({ item: i, place: w.title + " › " + b.title, showIf: b.showIf || null, group: w.id })
        }
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
                root.glassLink("glassBar", "The bar"),
                root.glassLink("glassBarPanels", "Menus and indicator")
            ] }
        ] },

        { id: "panels", group: "theme", name: "Panels", icon: "󰕮", description: "Launcher, clipboard, settings and wallpaper picker", sections: [
            { id: "glass", title: "Glass", items: [
                root.glassLink("glassLauncher", "App launcher"),
                root.glassLink("glassClipboard", "Clipboard"),
                root.glassLink("glassSettings", "Settings"),
                root.glassLink("glassWallpapers", "Wallpaper picker"),
                root.glassLink("glassWallpaperOverlay", "Wallpaper overlay"),
                { key: "popupOpacity", keywords: ["alpha", "transparency", "transparent", "translucent", "opacity", "see through", "glass", "launcher", "clipboard", "popup", "widget", "menu", "panel"], label: "Opacity", type: "number", kind: "real", min: 0.2, max: 1, step: 0.05, note: "Launcher and clipboard. Lower shows the desktop through" }
            ] },
            { id: "overlay", title: "Settings overlay", items: [
                { key: "scrimDim", keywords: ["dim", "dark", "darker", "veil", "background", "desktop", "scrim", "settings", "backdrop", "overlay"], label: "Desktop dim", type: "number", kind: "real", min: 0, max: 0.9, step: 0.05, note: "How much darker the desktop gets behind the settings. 0: as it is" }
            ] },
            { id: "shadow", title: "Shadow", note: "Under the launcher, clipboard and settings overlay", items: [
                { key: "popupShadow.opacity", keywords: root.shadowKeywords.concat(["launcher", "clipboard", "popup"]), label: "Opacity", type: "number", kind: "real", min: 0, max: 0.6, step: 0.05, note: "0 is off" },
                { key: "popupShadow.blur", keywords: root.shadowKeywords.concat(["soft", "spread", "size", "launcher", "clipboard", "popup"]), label: "Softness", type: "number", kind: "real", min: 4, max: 60, step: 1, note: "How far the shadow fades out" },
                { key: "popupShadow.offset", keywords: root.shadowKeywords.concat(["distance", "height", "launcher", "clipboard", "popup"]), label: "Drop", type: "number", kind: "real", min: 0, max: 30, step: 1, note: "How far it falls below the popup" }
            ] }
        ] },

        { id: "notifications", group: "theme", name: "Notifications", icon: "󰂚", description: "Popups from apps and the notification centre", actions: ["testNotification"], sections: [
            { id: "popups", title: "Popups", items: [
                root.glassLink("glassNotifications", "Glass"),
                { key: "notificationTimeout", keywords: ["notification", "notify", "popup", "toast", "timeout", "duration", "dismiss", "disappear", "how long"], label: "Show for", type: "number", kind: "real", min: 0, max: 60, step: 1, note: "Seconds. 0: until clicked away. Critical ones always stay" }
            ] },
            { id: "shadow", title: "Shadow", note: "Under the cards and the notification centre", items: [
                { key: "notificationShadow.opacity", keywords: root.shadowKeywords.concat(["notification", "notification centre", "history", "popup", "card"]), label: "Opacity", type: "number", kind: "real", min: 0, max: 0.6, step: 0.05, note: "0 is off" },
                { key: "notificationShadow.blur", keywords: root.shadowKeywords.concat(["soft", "spread", "size", "notification", "notification centre"]), label: "Softness", type: "number", kind: "real", min: 4, max: 60, step: 1, note: "How far the shadow fades out" },
                { key: "notificationShadow.offset", keywords: root.shadowKeywords.concat(["distance", "height", "notification", "notification centre"]), label: "Drop", type: "number", kind: "real", min: 0, max: 30, step: 1, note: "How far it falls below the card" }
            ] }
        ] },

        { id: "glass", group: "theme", name: "Glass", icon: "󰂵", description: "Live glass, the default look, and which widgets have a look of their own", sections: [
            { id: "general", title: "General", items: [
                { key: "glass", keywords: ["blur", "transparency", "liquid", "frosted", "capture", "effects", "acrylic"], label: "Live glass", type: "bool", note: "Off: no screen capture. May need a restart of the shells" },
                { key: "compositorGlass", keywords: ["blur", "lag", "latency", "lucent", "plugin", "hyprland", "compositor", "bar", "fast", "window"], label: "Compositor glass", type: "bool", note: "Drawn by the Lucent plugin, with no lag. Off or without the plugin: blurred from screen captures" }
            ] },
            { id: "look", title: "Default look", note: "Every widget follows it unless set to its own look below; window rules can follow it too", blocks: root.lookBlocks("glassDefault") },
            { id: "widgets", title: "Widgets", kind: "widgets", note: "Own look: change only what you want, the rest keeps following the default look", widgets: [
                root.widget("glassBar", "Status bar", "The bar and its small pills", ["bar", "status bar", "pill", "taskbar"]),
                root.widget("glassBarPanels", "Bar menus & indicator", "Wi-Fi, volume, power, notification centre, brightness and volume indicator", ["wifi", "volume", "power", "menu", "osd", "indicator", "notification centre", "history", "panel"]),
                root.widget("glassLauncher", "App launcher", "", ["launcher", "apps", "applications"]),
                root.widget("glassClipboard", "Clipboard", "", ["clipboard", "history", "paste"]),
                root.widget("glassSettings", "Settings", "The overlay and the window", ["settings"]),
                root.widget("glassWallpapers", "Wallpaper picker", "The picker window", ["wallpaper", "background", "picker"]),
                root.widget("glassWallpaperOverlay", "Wallpaper overlay", "Super+W: the blur behind the side pictures", ["wallpaper", "overlay", "carousel", "side"], ["Blur"]),
                root.widget("glassNotifications", "Notifications", "The notification cards", ["notification", "popup", "toast", "card"])
            ] },
            { id: "performance", title: "Performance", note: "What the blur costs", kind: "collapsed", items: [
                { key: "blurMaxTaps", keywords: ["blur", "quality", "performance", "cost", "samples", "taps", "gpu", "fast", "cheap", "expensive"], label: "Blur quality", type: "number", kind: "int", min: 4, max: 48, step: 2, note: "Samples per side: lower is cheaper" },
                { key: "blurTapsFalloff", keywords: ["blur", "quality", "performance", "cost", "samples", "taps", "gpu", "strength", "scaling", "adaptive"], label: "Fewer samples for stronger blur", type: "number", kind: "real", min: 0, max: 1, step: 0.1, note: "0: always the same. 1: fewer as the blur grows" }
            ] }
        ] }
    ]
}
