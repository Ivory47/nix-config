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
    // The bar's glass drawn by the compositor (no lag; needs the Lucent plugin, see ThemeDefaults.qml).
    readonly property bool compositorGlass: ThemeFromSettingsApp.bool("compositorGlass", ThemeDefaults.compositorGlass)
    readonly property real glassBlurRadius: ThemeFromSettingsApp.real("glassBlurRadius", ThemeDefaults.glassBlurRadius)
    readonly property int blurMaxTaps: ThemeFromSettingsApp.integer("blurMaxTaps", ThemeDefaults.blurMaxTaps)
    readonly property real blurTapsFalloff: ThemeFromSettingsApp.real("blurTapsFalloff", ThemeDefaults.blurTapsFalloff)
    readonly property real popupOpacity: ThemeFromSettingsApp.real("popupOpacity", ThemeDefaults.popupOpacity)
    readonly property real popupShadowOpacity: ThemeFromSettingsApp.real("popupShadowOpacity", ThemeDefaults.popupShadowOpacity)
    readonly property real popupShadowBlur: ThemeFromSettingsApp.real("popupShadowBlur", ThemeDefaults.popupShadowBlur)
    readonly property real popupShadowOffset: ThemeFromSettingsApp.real("popupShadowOffset", ThemeDefaults.popupShadowOffset)
    readonly property real notificationShadowOpacity: ThemeFromSettingsApp.real("notificationShadowOpacity", ThemeDefaults.notificationShadowOpacity)
    readonly property real notificationShadowBlur: ThemeFromSettingsApp.real("notificationShadowBlur", ThemeDefaults.notificationShadowBlur)
    readonly property real notificationShadowOffset: ThemeFromSettingsApp.real("notificationShadowOffset", ThemeDefaults.notificationShadowOffset)
    readonly property real notificationTimeout: ThemeFromSettingsApp.real("notificationTimeout", ThemeDefaults.notificationTimeout)
    readonly property real scrimDim: ThemeFromSettingsApp.real("scrimDim", ThemeDefaults.scrimDim)
    // The look of the glass (see ThemeDefaults.qml)
    readonly property real glassDefaultFrost: ThemeFromSettingsApp.real("glassDefaultFrost", ThemeDefaults.glassDefaultFrost)
    readonly property real glassDefaultTintStrength: ThemeFromSettingsApp.real("glassDefaultTintStrength", ThemeDefaults.glassDefaultTintStrength)
    readonly property real glassDefaultBrightness: ThemeFromSettingsApp.real("glassDefaultBrightness", ThemeDefaults.glassDefaultBrightness)
    readonly property real glassDefaultContrast: ThemeFromSettingsApp.real("glassDefaultContrast", ThemeDefaults.glassDefaultContrast)
    readonly property real glassDefaultSaturation: ThemeFromSettingsApp.real("glassDefaultSaturation", ThemeDefaults.glassDefaultSaturation)
    readonly property real glassDefaultBevel: ThemeFromSettingsApp.real("glassDefaultBevel", ThemeDefaults.glassDefaultBevel)
    readonly property real glassDefaultThickness: ThemeFromSettingsApp.real("glassDefaultThickness", ThemeDefaults.glassDefaultThickness)
    readonly property real glassDefaultBevelProfile: ThemeFromSettingsApp.real("glassDefaultBevelProfile", ThemeDefaults.glassDefaultBevelProfile)
    readonly property real glassDefaultRefraction: ThemeFromSettingsApp.real("glassDefaultRefraction", ThemeDefaults.glassDefaultRefraction)
    readonly property real glassDefaultIor: ThemeFromSettingsApp.real("glassDefaultIor", ThemeDefaults.glassDefaultIor)
    readonly property real glassDefaultDispersion: ThemeFromSettingsApp.real("glassDefaultDispersion", ThemeDefaults.glassDefaultDispersion)
    readonly property real glassDefaultShine: ThemeFromSettingsApp.real("glassDefaultShine", ThemeDefaults.glassDefaultShine)
    readonly property string glassPanelLook: ThemeFromSettingsApp.text("glassPanelLook", ThemeDefaults.glassPanelLook)
    readonly property string glassBarLook: ThemeFromSettingsApp.text("glassBarLook", ThemeDefaults.glassBarLook)
    // Derived (not settings): the tint the panels and the bar really use, after the default / own choice.
    readonly property real panelTintStrength: glassPanelLook === "own" ? glassPanelTintStrength : glassDefaultTintStrength
    readonly property real barTintStrength: glassBarLook === "own" ? glassBarTintStrength : glassDefaultTintStrength
    readonly property color barTint: glassBarLook === "own" ? glassBarTint : background
    readonly property real glassPanelFrost: ThemeFromSettingsApp.real("glassPanelFrost", ThemeDefaults.glassPanelFrost)
    readonly property real glassPanelTintStrength: ThemeFromSettingsApp.real("glassPanelTintStrength", ThemeDefaults.glassPanelTintStrength)
    readonly property real glassPanelBrightness: ThemeFromSettingsApp.real("glassPanelBrightness", ThemeDefaults.glassPanelBrightness)
    readonly property real glassPanelContrast: ThemeFromSettingsApp.real("glassPanelContrast", ThemeDefaults.glassPanelContrast)
    readonly property real glassPanelSaturation: ThemeFromSettingsApp.real("glassPanelSaturation", ThemeDefaults.glassPanelSaturation)
    readonly property real glassPanelBevel: ThemeFromSettingsApp.real("glassPanelBevel", ThemeDefaults.glassPanelBevel)
    readonly property real glassPanelThickness: ThemeFromSettingsApp.real("glassPanelThickness", ThemeDefaults.glassPanelThickness)
    readonly property real glassPanelBevelProfile: ThemeFromSettingsApp.real("glassPanelBevelProfile", ThemeDefaults.glassPanelBevelProfile)
    readonly property real glassPanelRefraction: ThemeFromSettingsApp.real("glassPanelRefraction", ThemeDefaults.glassPanelRefraction)
    readonly property real glassPanelIor: ThemeFromSettingsApp.real("glassPanelIor", ThemeDefaults.glassPanelIor)
    readonly property real glassPanelDispersion: ThemeFromSettingsApp.real("glassPanelDispersion", ThemeDefaults.glassPanelDispersion)
    readonly property real glassPanelShine: ThemeFromSettingsApp.real("glassPanelShine", ThemeDefaults.glassPanelShine)

    readonly property real glassBarFrost: ThemeFromSettingsApp.real("glassBarFrost", ThemeDefaults.glassBarFrost)
    // Follows `background` until the settings app sets its own colour.
    readonly property color glassBarTint: ThemeFromSettingsApp.color("glassBarTint", background)
    readonly property real glassBarTintStrength: ThemeFromSettingsApp.real("glassBarTintStrength", ThemeDefaults.glassBarTintStrength)
    readonly property real glassBarBrightness: ThemeFromSettingsApp.real("glassBarBrightness", ThemeDefaults.glassBarBrightness)
    readonly property real glassBarContrast: ThemeFromSettingsApp.real("glassBarContrast", ThemeDefaults.glassBarContrast)
    readonly property real glassBarSaturation: ThemeFromSettingsApp.real("glassBarSaturation", ThemeDefaults.glassBarSaturation)
    readonly property real glassBarBevel: ThemeFromSettingsApp.real("glassBarBevel", ThemeDefaults.glassBarBevel)
    readonly property real glassBarThickness: ThemeFromSettingsApp.real("glassBarThickness", ThemeDefaults.glassBarThickness)
    readonly property real glassBarBevelProfile: ThemeFromSettingsApp.real("glassBarBevelProfile", ThemeDefaults.glassBarBevelProfile)
    readonly property real glassBarRefraction: ThemeFromSettingsApp.real("glassBarRefraction", ThemeDefaults.glassBarRefraction)
    readonly property real glassBarIor: ThemeFromSettingsApp.real("glassBarIor", ThemeDefaults.glassBarIor)
    readonly property real glassBarDispersion: ThemeFromSettingsApp.real("glassBarDispersion", ThemeDefaults.glassBarDispersion)
    readonly property real glassBarShine: ThemeFromSettingsApp.real("glassBarShine", ThemeDefaults.glassBarShine)
    readonly property real backdropBlur: ThemeFromSettingsApp.real("backdropBlur", ThemeDefaults.backdropBlur)

    // Shape
    readonly property int radiusSmall: ThemeFromSettingsApp.integer("radiusSmall", ThemeDefaults.radiusSmall)
    readonly property int radiusMedium: ThemeFromSettingsApp.integer("radiusMedium", ThemeDefaults.radiusMedium)
    readonly property int radiusLarge: ThemeFromSettingsApp.integer("radiusLarge", ThemeDefaults.radiusLarge)

    readonly property string barCentreStyle: ThemeFromSettingsApp.text("barCentreStyle", ThemeDefaults.barCentreStyle)
    readonly property string barOsdStyle: ThemeFromSettingsApp.text("barOsdStyle", ThemeDefaults.barOsdStyle)
    readonly property string barLayout: ThemeFromSettingsApp.text("barLayout", ThemeDefaults.barLayout)
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
