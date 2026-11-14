#version 440
// Clean mode (see GlassBackdrop.clean): the compositor left our own surfaces out of the capture
// (the Pane Hyprland plugin), so the background IS the capture, cropped to our region. Replaces
// unmix.frag mode 0: nothing to subtract, nothing to divide by.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 capOrigin;  // where our region is inside the capture (uv): it may be the whole output
    vec2 capScale;
};

layout(binding = 1) uniform sampler2D capture;

void main() {
    fragColor = vec4(texture(capture, capOrigin + qt_TexCoord0 * capScale).rgb, 1.0);
}
