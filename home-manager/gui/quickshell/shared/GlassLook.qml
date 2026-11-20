import QtQuick

// One look of the glass in Theme (Theme.glassDefault, glassPanel, glassBar): the parameters of GlassStyle /
// the Lucent plugin's glass. Each is the settings app's value for "<name>.<parameter>" (e.g.
// "glassBar.tintStrength" in the settings file), else ThemeDefaults[name].<parameter>. Adding a parameter:
// a line here and a value in each of ThemeDefaults' three looks.
QtObject {
    // "glassDefault", "glassPanel" or "glassBar": the key in ThemeDefaults and the prefix in the file.
    required property string name
    // The tint colour while none is set (Theme.background; only the bar's look has its own setting).
    required property color fallbackTint

    readonly property var defaults: ThemeDefaults[name]

    readonly property color tint: ThemeFromSettingsApp.color(name + ".tint", fallbackTint)
    readonly property real frost: ThemeFromSettingsApp.real(name + ".frost", defaults.frost)
    readonly property real tintStrength: ThemeFromSettingsApp.real(name + ".tintStrength", defaults.tintStrength)
    readonly property real brightness: ThemeFromSettingsApp.real(name + ".brightness", defaults.brightness)
    readonly property real contrast: ThemeFromSettingsApp.real(name + ".contrast", defaults.contrast)
    readonly property real saturation: ThemeFromSettingsApp.real(name + ".saturation", defaults.saturation)
    readonly property real bevel: ThemeFromSettingsApp.real(name + ".bevel", defaults.bevel)
    readonly property real thickness: ThemeFromSettingsApp.real(name + ".thickness", defaults.thickness)
    readonly property real bevelProfile: ThemeFromSettingsApp.real(name + ".bevelProfile", defaults.bevelProfile)
    readonly property real refraction: ThemeFromSettingsApp.real(name + ".refraction", defaults.refraction)
    readonly property real ior: ThemeFromSettingsApp.real(name + ".ior", defaults.ior)
    readonly property real dispersion: ThemeFromSettingsApp.real(name + ".dispersion", defaults.dispersion)
    readonly property real shine: ThemeFromSettingsApp.real(name + ".shine", defaults.shine)
}
