import QtQuick
import qs.shared

// The look of the glass of the panels: the app launcher, the clipboard, the settings and the wallpaper picker (everything except the status bar), from the settings app's Glass section (Theme.glassPanel*; the
// defaults are in ThemeDefaults.qml). A GlassStyle with those values: set what is specific to the
// element (corner radius, which edges have a rim, the tint colour) where it is used.
GlassStyle {
    frost: Theme.glassPanelFrost
    tintStrength: Theme.glassPanelTintStrength
    brightness: Theme.glassPanelBrightness
    contrast: Theme.glassPanelContrast
    saturation: Theme.glassPanelSaturation
    bevel: Theme.glassPanelBevel
    thickness: Theme.glassPanelThickness
    bevelProfile: Theme.glassPanelBevelProfile
    refraction: Theme.glassPanelRefraction
    ior: Theme.glassPanelIor
    dispersion: Theme.glassPanelDispersion
    shine: Theme.glassPanelShine
}
