#version 440
// Clean mode (see GlassBackdrop.clean): there is no "wrong frame" to detect, because nothing of
// ours is in the capture. Replaces unmix.frag mode 1 with a one-texel "all good" statistic: no
// wrong pixels, none unknown (settle.frag then always takes the new background).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
};

void main() {
    fragColor = vec4(0.0, 0.0, 0.0, 1.0);
}
