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

    // The glass of the status bar, the popups and the settings drawn by the compositor (the
    // Lucent plugin's lucent_glass protocol) instead of from screen captures: blurred from what is
    // behind in the same frame, so it cannot lag, and nothing is captured. Used only while the
    // plugin offers the protocol (in a new enough version); otherwise the glass is the captured
    // one. It is the same glass (the plugin runs a copy of glass.frag with the same GlassStyle).
    // Applies live. On by default: without the plugin nothing changes, the shells capture as before.
    // (Off is for comparing, and for an output with a transform, where the plugin draws no glass.)
    readonly property bool compositorGlass: true

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
    // the glass it would break the background recovery). Opacity 0 turns it off; blur is how far it
    // fades out and offset how far it falls downwards, in logical pixels. (Theme.popupShadow.*)
    readonly property var popupShadow: ({ opacity: 0.4, blur: 24, offset: 8 })

    // How long a notification stays on the screen, in seconds (one with actions stays 1.6 times as
    // long; a notification that sets its own timeout keeps it; critical ones stay until closed).
    // 0 = until it is clicked away.
    readonly property real notificationTimeout: 5
    // The drop shadow of notification cards and of the notification centre (the history panel).
    readonly property var notificationShadow: ({ opacity: 0.35, blur: 28, offset: 10 })

    // How dark the desktop behind the settings overlay gets (the strength of the Background tint over
    // it; it is not blurred). 0: not darker.
    readonly property real scrimDim: 0.35

    // The look of the glass (the same parameters as the Lucent plugin's glass and GlassStyle; see
    // shared/glass/PanelGlassStyle.qml and BarGlassStyle.qml). `glassDefault` is the look everything follows
    // unless it has its own: `glassPanel` (the launcher, the clipboard, the settings and the wallpaper picker)
    // and `glassBar` (the status bar) are used only when glassPanelLook / glassBarLook is "own"; window rules
    // of the settings app can follow it too. The defaults are the look the shells had before these were
    // settings (the default look = the panels' look). The rim curve is only used by the compositor glass.

    // Each is a GlassLook in Theme (Theme.glassDefault.frost, ...); keys in the settings file "glassBar.frost".
    readonly property var glassDefault: ({
        frost: 1.0,
        tintStrength: 0.65,
        brightness: 0.02,
        contrast: 1.04,
        saturation: 1.2,
        bevel: 14,
        thickness: 0.7,
        bevelProfile: 3,
        refraction: 1.0,
        ior: 1.45,
        dispersion: 0.05,
        shine: 0.6
    })
    readonly property var glassPanel: ({
        frost: 1.0,
        tintStrength: 0.65,
        brightness: 0.02,
        contrast: 1.04,
        saturation: 1.2,
        bevel: 14,
        thickness: 0.7,
        bevelProfile: 3,
        refraction: 1.0,
        ior: 1.45,
        dispersion: 0.05,
        shine: 0.6
    })
    readonly property var glassBar: ({
        tint: "#1e1e2e",   // only the bar has a tint colour setting (follows Background until set)
        frost: 0.9,
        tintStrength: 0.35,
        brightness: 0.02,
        contrast: 1.04,
        saturation: 1.2,
        bevel: 14,
        thickness: 0.7,
        bevelProfile: 3,
        refraction: 1.0,
        ior: 1.45,
        dispersion: 0.05,
        shine: 0.6
    })

    readonly property string glassPanelLook: "default"   // "default": follow the default look; "own": glassPanel
    readonly property string glassBarLook: "own"         // "default" or "own" (glassBar, with its tint colour)

    // Backdrop blur, used by shared/BackdropBlur.qml (independent of the compositor's blur).
    // 0.0 = off, 1.0 = strongest. Every config that uses BackdropBlur inherits this value.
    readonly property real backdropBlur: 0.8

    // Shape
    readonly property int radiusSmall: 5
    readonly property int radiusMedium: 6
    readonly property int radiusLarge: 8

    readonly property int statusBarHeight: 50
    // How the status bar is laid out: classic, balanced, islands or notch (see status-bar/).
    readonly property string barLayout: "balanced"
    // The date and time in the middle of the "balanced" bar: capsule, stacked or rule.
    readonly property string barCentreStyle: "stacked"
    // The brightness / volume indicator of the "balanced" bar: simple, bubble or dock.
    readonly property string barOsdStyle: "simple"
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
