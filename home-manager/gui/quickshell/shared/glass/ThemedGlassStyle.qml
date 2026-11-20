import QtQuick
import qs.shared

// A GlassStyle with the values of one of Theme's glass looks: pass the look a widget uses,
// `look: Theme.glassLauncher.inUse` (its own look or the default look). Set what is specific to the element
// (corner radius, which edges have a rim) where it is used.
GlassStyle {
    required property GlassLook look

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
