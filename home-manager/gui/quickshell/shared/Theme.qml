pragma Singleton

import QtQuick

// What every Quickshell config (status-bar, app-launcher, clipboard, settings) uses: `Theme.x`.
// Each value is ThemeDefaults.qml's, unless the settings app has set it (ThemeFromSettingsApp.qml).
// Edit the defaults in ThemeDefaults.qml; the settings app never changes that file. To add a
// value: add it to ThemeDefaults.qml and a line here with the same name.
// default.nix copies this folder into each config at build time (`import qs.shared`).
QtObject {
    readonly property var defaults: ThemeDefaults

    // Colors
    readonly property color background: ThemeFromSettingsApp.color("background", ThemeDefaults.background)
    readonly property color surface: ThemeFromSettingsApp.color("surface", ThemeDefaults.surface)
    readonly property color surfaceAlt: ThemeFromSettingsApp.color("surfaceAlt", ThemeDefaults.surfaceAlt)

    readonly property color text: ThemeFromSettingsApp.color("text", ThemeDefaults.text)
    readonly property color textMuted: ThemeFromSettingsApp.color("textMuted", ThemeDefaults.textMuted)
    readonly property color textSecondary: ThemeFromSettingsApp.color("textSecondary", ThemeDefaults.textSecondary)

    readonly property color accent: ThemeFromSettingsApp.color("accent", ThemeDefaults.accent)

    readonly property color green: ThemeFromSettingsApp.color("green", ThemeDefaults.green)
    readonly property color orange: ThemeFromSettingsApp.color("orange", ThemeDefaults.orange)
    readonly property color red: ThemeFromSettingsApp.color("red", ThemeDefaults.red)

    readonly property color shadowColor: ThemeFromSettingsApp.color("shadowColor", ThemeDefaults.shadowColor)

    // Status bar
    readonly property color barBorderColor: ThemeFromSettingsApp.color("barBorderColor", ThemeDefaults.barBorderColor)
    readonly property real barBorderOpacity: ThemeFromSettingsApp.real("barBorderOpacity", ThemeDefaults.barBorderOpacity)
    // Opacity of the bar's plain fill (the colour is `background`), used when the glass is off.
    readonly property real barFillOpacity: ThemeFromSettingsApp.real("barFillOpacity", ThemeDefaults.barFillOpacity)

    // Glass (a changed `glass` may need a restart of the shells, see ThemeDefaults.qml)
    readonly property bool glass: ThemeFromSettingsApp.bool("glass", ThemeDefaults.glass)
    readonly property real glassBlurRadius: ThemeFromSettingsApp.real("glassBlurRadius", ThemeDefaults.glassBlurRadius)
    readonly property real scrimBlurRadius: ThemeFromSettingsApp.real("scrimBlurRadius", ThemeDefaults.scrimBlurRadius)
    readonly property real backdropBlur: ThemeFromSettingsApp.real("backdropBlur", ThemeDefaults.backdropBlur)

    // Shape
    readonly property int radiusSmall: ThemeFromSettingsApp.integer("radiusSmall", ThemeDefaults.radiusSmall)
    readonly property int radiusMedium: ThemeFromSettingsApp.integer("radiusMedium", ThemeDefaults.radiusMedium)
    readonly property int radiusLarge: ThemeFromSettingsApp.integer("radiusLarge", ThemeDefaults.radiusLarge)

    readonly property int statusBarHeight: ThemeFromSettingsApp.integer("statusBarHeight", ThemeDefaults.statusBarHeight)
    readonly property int osdIndicatorWidth: ThemeFromSettingsApp.integer("osdIndicatorWidth", ThemeDefaults.osdIndicatorWidth)

    // Spacing
    readonly property int spacingSmall: ThemeFromSettingsApp.integer("spacingSmall", ThemeDefaults.spacingSmall)
    readonly property int spacingMedium: ThemeFromSettingsApp.integer("spacingMedium", ThemeDefaults.spacingMedium)
    readonly property int spacingLarge: ThemeFromSettingsApp.integer("spacingLarge", ThemeDefaults.spacingLarge)

    // Typography
    readonly property int textSmall: ThemeFromSettingsApp.integer("textSmall", ThemeDefaults.textSmall)
    readonly property int textMedium: ThemeFromSettingsApp.integer("textMedium", ThemeDefaults.textMedium)
    readonly property int textLarge: ThemeFromSettingsApp.integer("textLarge", ThemeDefaults.textLarge)
}
