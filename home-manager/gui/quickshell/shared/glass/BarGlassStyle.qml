import QtQuick
import qs.shared

// The look of the glass of the status bar, from the settings app's Glass section (Theme.glassBar*; the
// defaults are in ThemeDefaults.qml). A GlassStyle with those values: set what is specific to the
// element (corner radius, which edges have a rim, the tint colour) where it is used.
GlassStyle {
    frost: Theme.glassBarFrost
    tint: Theme.glassBarTint
    tintStrength: Theme.glassBarTintStrength
    brightness: Theme.glassBarBrightness
    contrast: Theme.glassBarContrast
    saturation: Theme.glassBarSaturation
    bevel: Theme.glassBarBevel
    thickness: Theme.glassBarThickness
    bevelProfile: Theme.glassBarBevelProfile
    refraction: Theme.glassBarRefraction
    ior: Theme.glassBarIor
    dispersion: Theme.glassBarDispersion
    shine: Theme.glassBarShine
}
