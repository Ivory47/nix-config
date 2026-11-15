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

    // Cost of the blur: the most samples each blur pass takes per side of a pixel (the GPU time
    // grows with it). A wider blur than this many texels spreads the samples out instead of
    // taking more, so the picture stays almost the same; very low values start to look grainy.
    readonly property int blurMaxTaps: 48

    // How much the sample count falls as the blur gets stronger than radius 14: 0 = not at all,
    // 1 = inversely with the radius (twice the blur, half the samples). A wide blur hides the
    // coarser sampling, so the cost stops growing, or even shrinks, with strength.
    readonly property real blurTapsFalloff: 0.0

    // Opacity of the app launcher's and clipboard popup's glass: 1 = the glass as it is (the blurred
    // background under the tint), lower lets the live desktop show through it. (The settings app is
    // not affected.)
    readonly property real popupOpacity: 1.0

    // Drop shadow around the app launcher and the clipboard popup (outside the panel only; under
    // the glass it would break the background recovery). Opacity 0 turns it off.
    readonly property real popupShadowOpacity: 0.3
    readonly property real popupShadowBlur: 24      // how far it fades out, logical pixels
    readonly property real popupShadowOffset: 8     // how far it falls downwards

    // Blur strength of the settings app, which blurs the whole desktop while it is open (the
    // blurred picture is shared by that veil and the settings panel). Sigma in logical pixels.
    readonly property real scrimBlurRadius: 10.5

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
