pragma Singleton

import QtQuick

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

    // Shape
    readonly property int radiusSmall: 5
    readonly property int radiusMedium: 6
    readonly property int radiusLarge: 8

    readonly property int statusBarHeight: 30
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
