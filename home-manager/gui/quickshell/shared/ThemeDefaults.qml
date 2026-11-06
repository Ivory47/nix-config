pragma Singleton

import QtQuick

// The default value of every theme setting. Configs do not use this directly: they use `Theme`
// (Theme.qml), which is these values with the settings app's changes laid over them
// (ThemeFromSettingsApp.qml). Edit the defaults here; the settings app never writes this file.
// Adding a value here also needs a line with the same name in Theme.qml.
QtObject {
    // Colors
    readonly property color background: "#1e1e2e"
    readonly property color surface: "#313244"
    readonly property color surfaceAlt: "#45475a"

    readonly property color text: "#ffffff"
    readonly property color textMuted: "#888888"
    readonly property color textSecondary: "#cdd6f4"

    readonly property color accent: "#cdd6f4"

    readonly property color green: "#a6e3a1"
    readonly property color orange: "#fab387"
    readonly property color red: "#f38ba8"

    readonly property color shadowColor: "#80000000"

    // Status bar
    readonly property color barBorderColor: "#494965"  // the line under the bar
    readonly property real barBorderOpacity: 0.85
    // Opacity of the bar's plain fill (its colour is `background`); only shown when `glass` is off.
    readonly property real barFillOpacity: 0.55

    // Live glass for the status bar, app launcher and clipboard: the blurred, refracting backdrop
    // the shell computes itself (shared/glass/). One switch for all three.
    // false: no screen capture and none of the glass pipeline runs (no GPU or compositor cost);
    // the bar is a plain translucent rectangle and the popups a plain tinted panel (the row
    // highlights stay). Applies after `hms` and `qsr`.
    readonly property bool glass: true

    // Blur strength of the glass on the bar and on the popups: gaussian sigma in logical pixels.
    readonly property real glassBlurRadius: 14

    // Backdrop blur, used by shared/BackdropBlur.qml (independent of the compositor's blur).
    // 0.0 = off, 1.0 = strongest. Every config that uses BackdropBlur inherits this value.
    readonly property real backdropBlur: 0.8

    // Shape
    readonly property int radiusSmall: 5
    readonly property int radiusMedium: 6
    readonly property int radiusLarge: 8

    readonly property int statusBarHeight: 50
    readonly property int osdIndicatorWidth: 120

    // Spacing
    readonly property int spacingSmall: 5
    readonly property int spacingMedium: 10
    readonly property int spacingLarge: 15

    // Typography
    readonly property int textSmall: 13
    readonly property int textMedium: 14
    readonly property int textLarge: 20
}
