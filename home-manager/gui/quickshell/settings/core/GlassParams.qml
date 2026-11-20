pragma Singleton

import QtQuick

// The look parameters of glass, defined ONCE for both places that edit them: a Theme look (ThemeSchema:
// Theme.<look>.<themeKey>) and a window rule's `lucent_glass` (HyprlandStore: the rule key `key`). Ranges, steps,
// labels and notes are the Theme pages'. To add a parameter: an entry here (in its block's place), the
// GlassLook property in shared/ThemeDefaults.qml, and the plugin key in HyprlandStore if it needs more.
//
// { block: "Tone" | "Rim" | "Light", key: lucent_glass key, themeKey: the GlassLook property, label,
//   themeLabel (optional: the Theme page's shorter label), type: "color" (else a number: min, max, step),
//   def: what the plugin uses when a rule leaves the key out, note, ruleNote (optional: the note in a rule),
//   words: extra search words of the Theme page }
QtObject {
    readonly property var look: [
        { block: "Tone", key: "frost", themeKey: "frost", label: "Frost", min: 0, max: 1, step: 0.05, def: 1,
            note: "1: only the blurred picture. Lower: some sharp shows", words: ["blurred", "sharp", "transparency"] },
        { block: "Tone", key: "tint", themeKey: "tint", label: "Tint colour", type: "color", def: "#000000",
            note: "Mixed in with the tint strength", words: ["tint", "colour", "color", "background", "hue"] },
        { block: "Tone", key: "tint_strength", themeKey: "tintStrength", label: "Tint strength", themeLabel: "Tint", min: 0, max: 1, step: 0.05, def: 0,
            note: "How much background colour is mixed in", ruleNote: "0: no tint (with a tint colour alone: 0.25)",
            words: ["tint", "colour", "color", "background", "dark", "opaque", "opacity", "hide"] },
        { block: "Tone", key: "brightness", themeKey: "brightness", label: "Brightness", min: -0.5, max: 0.5, step: 0.01, def: 0,
            note: "Added to what is behind", words: ["light", "dark", "lighten", "darken", "tone"] },
        { block: "Tone", key: "contrast", themeKey: "contrast", label: "Contrast", min: 0.5, max: 1.5, step: 0.01, def: 1,
            words: ["tone", "flat", "sharpen"] },
        { block: "Tone", key: "saturation", themeKey: "saturation", label: "Saturation", min: 0, max: 2, step: 0.05, def: 1,
            note: "0 is grey", words: ["colour", "color", "vivid", "grey", "gray", "tone"] },
        { block: "Rim", key: "bevel", themeKey: "bevel", label: "Width", min: 0, max: 40, step: 1, def: 0,
            note: "The curved glass edge, in px. 0 is flat", words: ["rim", "width", "curved"] },
        { block: "Rim", key: "thickness", themeKey: "thickness", label: "Height", min: 0, max: 2, step: 0.05, def: 0,
            note: "How far the rim bends what is behind", words: ["rim", "height", "depth", "lens"] },
        { block: "Rim", key: "bevel_profile", themeKey: "bevelProfile", label: "Curve", min: 2, max: 4, step: 0.5, def: 3,
            note: "2 round, 3 smooth, 4 smoothest. Compositor glass only", words: ["rim", "curve", "profile", "smooth", "shape"] },
        { block: "Light", key: "refraction", themeKey: "refraction", label: "Refraction", min: 0, max: 4, step: 0.1, def: 0,
            note: "How strongly the rim bends the background", ruleNote: "Needs a rim width and height",
            words: ["bend", "lens", "distortion", "magnify"] },
        { block: "Light", key: "ior", themeKey: "ior", label: "Index of refraction", min: 1, max: 3, step: 0.05, def: 1.45,
            note: "Higher bends more. 1.45 is glass", words: ["index", "refraction", "ior", "bend", "lens"] },
        { block: "Light", key: "dispersion", themeKey: "dispersion", label: "Dispersion", min: 0, max: 0.5, step: 0.01, def: 0,
            note: "Coloured fringes along the rim", words: ["fringe", "rainbow", "chromatic", "colour", "color"] },
        { block: "Light", key: "shine", themeKey: "shine", label: "Shine", min: 0, max: 2, step: 0.05, def: 0,
            note: "Light that catches the rim", words: ["light", "highlight", "gloss", "reflection", "glow"] }
    ]

    // One parameter by its lucent_glass key or its GlassLook property.
    function byThemeKey(themeKey) {
        return look.find(p => p.themeKey === themeKey)
    }
}
