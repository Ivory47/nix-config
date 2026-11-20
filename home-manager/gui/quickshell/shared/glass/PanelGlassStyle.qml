import QtQuick
import qs.shared

// The look of the glass of the panels: the app launcher, the clipboard, the settings and the wallpaper
// picker (everything except the status bar), from the settings app's Panels page: the default look
// (Theme.glassDefault, set on the Glass page) unless Theme.glassPanelLook is "own" (Theme.glassPanel).
// The defaults are in ThemeDefaults.qml. A GlassStyle with those values: set what is specific to the
// element (corner radius, which edges have a rim, the tint colour) where it is used.
GlassStyle {
    // The look in use: its own or the default one (Theme.panelGlass, after Theme.glassPanelLook).
    readonly property GlassLook look: Theme.panelGlass

    frost: look.frost
    tintStrength: look.tintStrength
    brightness: look.brightness
    contrast: look.contrast
    saturation: look.saturation
    bevel: look.bevel
    thickness: look.thickness
    bevelProfile: look.bevelProfile
    refraction: look.refraction
    ior: look.ior
    dispersion: look.dispersion
    shine: look.shine
}
