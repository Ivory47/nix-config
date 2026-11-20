import QtQuick
import qs.shared

// The look of the glass of the status bar, from the settings app's Status bar page: its own look
// (Theme.glassBar*, the default: Theme.glassBarLook "own") or the default look (Theme.glassDefault*, set on
// the Glass page). The defaults are in ThemeDefaults.qml. A GlassStyle with those values: set what is specific to the
// element (corner radius, which edges have a rim, the tint colour) where it is used.
GlassStyle {
    // Its own look (Theme.glassBar*) or the default look (Theme.glassDefault*).
    readonly property bool own: Theme.glassBarLook === "own"

    // Its tint colour only with its own look; the default look tints with Background.
    tint: Theme.barTint
    frost: own ? Theme.glassBarFrost : Theme.glassDefaultFrost
    tintStrength: own ? Theme.glassBarTintStrength : Theme.glassDefaultTintStrength
    brightness: own ? Theme.glassBarBrightness : Theme.glassDefaultBrightness
    contrast: own ? Theme.glassBarContrast : Theme.glassDefaultContrast
    saturation: own ? Theme.glassBarSaturation : Theme.glassDefaultSaturation
    bevel: own ? Theme.glassBarBevel : Theme.glassDefaultBevel
    thickness: own ? Theme.glassBarThickness : Theme.glassDefaultThickness
    bevelProfile: own ? Theme.glassBarBevelProfile : Theme.glassDefaultBevelProfile
    refraction: own ? Theme.glassBarRefraction : Theme.glassDefaultRefraction
    ior: own ? Theme.glassBarIor : Theme.glassDefaultIor
    dispersion: own ? Theme.glassBarDispersion : Theme.glassDefaultDispersion
    shine: own ? Theme.glassBarShine : Theme.glassDefaultShine
}
