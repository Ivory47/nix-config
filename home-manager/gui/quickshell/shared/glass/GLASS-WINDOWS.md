# Compositor glass for a Quickshell window (quick guide)

The Lucent plugin draws the glass for you, in the compositor's own frame, behind your window's
content. Your component only says *where* the glass is and *what it looks like*. This works for
layer-shell windows (`PanelWindow`, `GlassPopup`) and for normal windows (`FloatingWindow`).

What was run for this guide: a transparent `FloatingWindow` and a `PanelWindow` with a `LucentGlass`
(the code below), in a nested Hyprland. `LucentGlassPanel` is the same item with a `GlassStyle` bound
to it and is what the bar and the popups use today.

## 1. The minimum

```qml
import QtQuick
import Quickshell
import Glass.Native

FloatingWindow {
    color: "transparent"                     // the glass shows through the window: it must be transparent

    LucentGlass {
        id: glass
        x: 40; y: 40                         // the glass is the area of this item
        width: parent.width - 80
        height: parent.height - 80
        active: true                         // false: no glass (and nothing is drawn)
        blurRadius: 14                       // sigma of the blur, logical px
        cornerRadius: 20
    }

    // Your content goes over the glass as usual.
    Text { x: 60; y: 60; text: "hello"; color: "white" }
}
```

- The window's own content is drawn over the glass. Leave the glass area transparent, or draw
  only what belongs on top of it (text, a tint, highlights).
- The region follows the item (position, size, fractions of a pixel, `visible`), also on
  fractional scales. You do not send anything yourself.
- Several `LucentGlass` items in one window are fine (e.g. a veil and a panel).
- Hyprland's own blur is switched off for a window while it has visible glass: no `no_blur`
  rule is needed, and nothing is blurred twice.

## 2. Check that it is there, and have a fallback

`glass.available` is true when the plugin is loaded and new enough: **3** for a layer surface,
**4** for a normal window (an older plugin draws glass behind layers only, so a window would show
nothing). It changes when the plugin is loaded or unloaded, so bind to it:

```qml
LucentGlass { id: glass; active: true; /* ... */ }

Rectangle {                                   // used when there is no compositor glass
    anchors.fill: glass
    visible: !glass.available
    color: Qt.rgba(0.1, 0.12, 0.16, 0.8)
    radius: glass.cornerRadius
}
```

Unloading the plugin under a running window is handled: the object is dropped without a request
(a request on it would be a protocol error), and `available` goes false. Loading it again brings
the glass back (tested 5 rounds).

## 3. Use the shared look (`GlassStyle`, `LucentGlassPanel`)

`LucentGlassPanel` is a `LucentGlass` with a `style: GlassStyle` bound to it, so a component takes
the same look as the bar and the popups instead of repeating numbers:

```qml
LucentGlassPanel {
    anchors.fill: parent
    active: Theme.glass && Theme.compositorGlass && available
    blurRadius: 14                            // not in the style: set it here (Theme.glassBlurRadius is the popups' default)
    maxTaps: Theme.blurMaxTaps                // blur cost cap; 0 = the compositor's default
    style: GlassStyle { cornerRadius: Theme.radiusLarge; bevel: 12 }   // anything you leave out is the default
}
```

Use one `GlassStyle` object for several panels to keep them identical. The properties you can set
on the style or directly on the item (the item's own names are the same):

| Property | Meaning |
| --- | --- |
| `blurRadius`, `maxTaps` | blur sigma (logical px, **on the item, not in the style**) and its cost cap |
| `frost` | 0..1, how much of the blurred background shows instead of the sharp one |
| `cornerRadius` | rounds the glass (logical px) |
| `bevel`, `thickness`, `edges` | rim width (px), rim height relative to its width, which edges have a rim: `Qt.vector4d(left, top, right, bottom)`, 1 = rim |
| `bevelProfile` | rim curve exponent: 2 = quarter circle, **3 = default** (bending fades out smoothly), 4 = smoothest (needs plugin version 5; older plugins ignore it) |
| `refraction`, `ior`, `dispersion` | how the rim bends the background, index of refraction, coloured fringes |
| `shine`, `lightDir` | light on the rim, and where it comes from (y down) |
| `tint`, `tintStrength` | colour mixed into the glass, and how much |
| `brightness`, `contrast`, `saturation` | tone of the background (0, 1, 1 = unchanged) |
| `glassOpacity` (`style.opacity`) | below 1 the sharp background shows through |
| `hlRect0..2`, `hlColor0..2`, `hlRadius` | up to three highlight rectangles in the glass (a selected row, a field): rect = x, y, width, height **relative to the glass item**, colour = r, g, b, strength |
| `holeRect`, `holeRadius` | a rounded rectangle cut out of the glass (a veil that leaves a panel out) |

Ranges and defaults are in Lucent's README (the same names, as keys of the window rule).
`GlassStyle.alpha` and the tag/backdrop parts are for the captured glass only: the compositor
glass does not use them. Do not use `GlassBackdrop` or `GlassTag` for a window with compositor glass.

## 4. A normal window: the Hyprland side

A `FloatingWindow` is a normal Hyprland window, so it is placed by window rules, not by the shell:

```lua
hl.window_rule({
    name  = "my-glass-window",
    match = { class = "^your.window.class$" },   -- see `hyprctl clients` for the class and title
    float = true,
    size  = "900 560",
    center = true,
    rounding = 0,                                 -- see below
})
```

- **Rounding:** Hyprland rounds only the window's own content, not the glass. Give the window
  `rounding = 0` and let the glass round itself with `cornerRadius` (this combination was not
  tested).
- **Title rules:** a `FloatingWindow`'s title can be set after it is mapped, so a rule that
  matches on the title may miss it. Match on the class, or float/size it with a dispatcher.
- Window opacity and fades apply to the glass too (it fades with the window; tried with the
  `inactive_opacity` setting, not with an `opacity` window rule).
- Fullscreen, moving, resizing, workspace slides: the glass follows (tested). Popups and
  subsurfaces of the window get no glass, only its main surface.

## 5. Not covered / open

- Hiding and showing by toggling the window's `visible`: not tested with only `LucentGlass`
  (the old rule not to toggle `visible` was for the captured glass). `LucentGlass` re-creates its
  object when the window's surface is made anew, but that path is untested for a re-shown window.
  Use `active: false` or `visible: false` on the glass item to hide only the glass.
- No glass without the plugin, and none on monitors with a transform.
- A program that cannot ask for glass (a terminal) can get it from the `lucent_glass` window rule
  instead: see Lucent's README.
