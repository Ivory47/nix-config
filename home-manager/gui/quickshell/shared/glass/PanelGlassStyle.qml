import QtQuick
import qs.shared

// The look of the glass of the panels: the app launcher, the clipboard, the settings and the wallpaper
// picker (everything except the status bar), from the settings app's Panels page: the default look
// (Theme.glassDefault*, set on the Glass page) unless Theme.glassPanelLook is "own" (Theme.glassPanel*).
// The defaults are in ThemeDefaults.qml. A GlassStyle with those values: set what is specific to the
// element (corner radius, which edges have a rim, the tint colour) where it is used.
GlassStyle {
    // Its own look (Theme.glassPanel*) or the default look (Theme.glassDefault*).
    readonly property bool own: Theme.glassPanelLook === "own"

    frost: own ? Theme.glassPanelFrost : Theme.glassDefaultFrost
    tintStrength: own ? Theme.glassPanelTintStrength : Theme.glassDefaultTintStrength
    brightness: own ? Theme.glassPanelBrightness : Theme.glassDefaultBrightness
    contrast: own ? Theme.glassPanelContrast : Theme.glassDefaultContrast
    saturation: own ? Theme.glassPanelSaturation : Theme.glassDefaultSaturation
    bevel: own ? Theme.glassPanelBevel : Theme.glassDefaultBevel
    thickness: own ? Theme.glassPanelThickness : Theme.glassDefaultThickness
    bevelProfile: own ? Theme.glassPanelBevelProfile : Theme.glassDefaultBevelProfile
    refraction: own ? Theme.glassPanelRefraction : Theme.glassDefaultRefraction
    ior: own ? Theme.glassPanelIor : Theme.glassDefaultIor
    dispersion: own ? Theme.glassPanelDispersion : Theme.glassDefaultDispersion
    shine: own ? Theme.glassPanelShine : Theme.glassDefaultShine
}
