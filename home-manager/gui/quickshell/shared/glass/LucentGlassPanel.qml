import QtQuick
import Glass.Native

// A piece of glass drawn by the compositor (the Lucent plugin, see native/lucentglass.hpp): the
// counterpart of GlassPanel, with the same `style` and the same highlights and hole, but nothing
// is drawn here. The plugin draws the glass under the window's content, from what is behind the
// window in the same frame, so it is never behind. The window must be transparent where this
// item is, except for what belongs on top of the glass.
//
// Use it while `available` is true (the plugin is loaded and new enough) and a GlassPanel
// otherwise.
LucentGlass {
    property GlassStyle style: GlassStyle {}

    frost: style.frost
    bevel: style.bevel
    thickness: style.thickness
    cornerRadius: style.cornerRadius
    edges: style.edges
    refraction: style.refraction
    ior: style.ior
    dispersion: style.dispersion
    tint: style.tint
    tintStrength: style.tintStrength
    brightness: style.brightness
    contrast: style.contrast
    saturation: style.saturation
    shine: style.shine
    lightDir: style.lightDir
    glassOpacity: style.opacity
}
