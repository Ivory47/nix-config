import QtQuick

// One look of the glass in Theme: the default look (Theme.glassDefault) or a widget's (Theme.glassBar,
// glassLauncher, ...). Each parameter is the settings app's value for "<name>.<parameter>" (the file nests
// them: {"glassLauncher": {"tintStrength": 0.4}}), else ThemeDefaults[name].<parameter>, else, for a
// widget, the default look's value (live: a widget's own look only changes what it sets).
// A widget uses `inUse`: its own look while `look` is "own", else the default look.
// Adding a parameter: a line here and a value in ThemeDefaults.glassDefault.
QtObject {
    id: root

    // The key in ThemeDefaults and the group in the file: "glassDefault", "glassBar", "glassLauncher", ...
    required property string name
    // The default look, for a widget's look (null for the default look itself).
    property GlassLook base: null
    // The default look's tint colour and blur radius while none is set (Theme.background, glassBlurRadius).
    property color fallbackTint: "black"
    property real fallbackBlur: 14

    readonly property var defaults: ThemeDefaults[name]

    // "default" (follow `base`) or "own". The default look is always its own.
    readonly property string look: base ? ThemeFromSettingsApp.text(name + ".look", defaults.look || "default") : "own"
    readonly property bool own: look === "own"
    readonly property GlassLook inUse: own ? root : base

    // This look's default for a parameter: its own, else the default look's current value.
    function fallback(p) {
        if (defaults[p] !== undefined)
            return defaults[p]
        if (base)
            return base[p]
        return p === "tint" ? fallbackTint : p === "blurRadius" ? fallbackBlur : undefined
    }

    // What a parameter is while the file does not set it (the settings app compares with this).
    function defaultOf(p) {
        if (p === "look")
            return base ? (defaults.look || "default") : "own"
        return fallback(p)
    }

    // How strongly what is behind is blurred (sigma, logical px). The default look's is the setting
    // `glassBlurRadius` (fallbackBlur), not a key of its own.
    readonly property real blurRadius: base ? ThemeFromSettingsApp.real(name + ".blurRadius", fallback("blurRadius")) : fallbackBlur
    readonly property color tint: ThemeFromSettingsApp.color(name + ".tint", fallback("tint"))
    readonly property real frost: ThemeFromSettingsApp.real(name + ".frost", fallback("frost"))
    readonly property real tintStrength: ThemeFromSettingsApp.real(name + ".tintStrength", fallback("tintStrength"))
    readonly property real brightness: ThemeFromSettingsApp.real(name + ".brightness", fallback("brightness"))
    readonly property real contrast: ThemeFromSettingsApp.real(name + ".contrast", fallback("contrast"))
    readonly property real saturation: ThemeFromSettingsApp.real(name + ".saturation", fallback("saturation"))
    readonly property real bevel: ThemeFromSettingsApp.real(name + ".bevel", fallback("bevel"))
    readonly property real thickness: ThemeFromSettingsApp.real(name + ".thickness", fallback("thickness"))
    readonly property real bevelProfile: ThemeFromSettingsApp.real(name + ".bevelProfile", fallback("bevelProfile"))
    readonly property real refraction: ThemeFromSettingsApp.real(name + ".refraction", fallback("refraction"))
    readonly property real ior: ThemeFromSettingsApp.real(name + ".ior", fallback("ior"))
    readonly property real dispersion: ThemeFromSettingsApp.real(name + ".dispersion", fallback("dispersion"))
    readonly property real shine: ThemeFromSettingsApp.real(name + ".shine", fallback("shine"))
}
