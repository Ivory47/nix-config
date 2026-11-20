import QtQuick
import qs.shared

// The look of the glass of the status bar, from the settings app's Status bar page: its own look
// (Theme.glassBar, the default: Theme.glassBarLook "own") or the default look (Theme.glassDefault, set on
// the Glass page). The defaults are in ThemeDefaults.qml. A GlassStyle with those values: set what is specific to the
// element (corner radius, which edges have a rim, the tint colour) where it is used.
GlassStyle {
    // The look in use: its own or the default one (Theme.barGlass, after Theme.glassBarLook).
    readonly property GlassLook look: Theme.barGlass

    tint: look.tint
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
