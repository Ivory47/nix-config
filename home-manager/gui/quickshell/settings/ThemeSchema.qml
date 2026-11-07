pragma Singleton

import QtQuick

// Every value of Theme.qml, in groups, as the settings app lists it: what the Theme page shows
// and what the search finds. One entry per value (`key` is the Theme property):
//   key, label, type ("color" | "number" | "bool"), kind ("int" | "real", numbers), min, max, step,
//   alpha (colours with transparency), note (small grey text), keywords (synonyms for the search).
// A section can have a `button` (an action of ThemePage, shown next to its title).
QtObject {
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
        { title: "Glass", items: [
            { key: "glass", keywords: ["blur", "transparency", "liquid", "frosted", "capture", "effects", "acrylic"], label: "Live glass", type: "bool", note: "Off: no screen capture. May need a restart of the shells" },
            { key: "glassBlurRadius", keywords: ["blur", "frosted", "strength", "sigma", "bar", "popup", "launcher"], label: "Blur radius", type: "number", kind: "real", min: 0, max: 40, step: 1, note: "Bar and popups" },
            { key: "scrimBlurRadius", keywords: ["blur", "dim", "veil", "background", "strength", "desktop"], label: "Settings desktop blur", type: "number", kind: "real", min: 0, max: 40, step: 0.5, note: "Blur of the desktop behind the settings" },
            { key: "backdropBlur", keywords: ["blur", "legacy", "strength"], label: "Legacy blur", type: "number", kind: "real", min: 0, max: 1, note: "Unused" }
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
