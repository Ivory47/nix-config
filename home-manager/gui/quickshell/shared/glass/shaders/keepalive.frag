#version 440
// A consumer that exists only so that Qt renders the textures it samples when they are scheduled
// (see the keep-alive item in GlassBackdrop.qml): one item and one draw call for all of them,
// instead of one each. Its output is never seen, but it depends on every sampler, so that none
// of them is optimised away (an unused sampler is no reference to its texture).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
};

layout(binding = 1) uniform sampler2D k0;
layout(binding = 2) uniform sampler2D k1;
layout(binding = 3) uniform sampler2D k2;
layout(binding = 4) uniform sampler2D k3;
layout(binding = 5) uniform sampler2D k4;
layout(binding = 6) uniform sampler2D k5;
layout(binding = 7) uniform sampler2D k6;
layout(binding = 8) uniform sampler2D k7;
layout(binding = 9) uniform sampler2D k8;
layout(binding = 10) uniform sampler2D k9;
layout(binding = 11) uniform sampler2D k10;
layout(binding = 12) uniform sampler2D k11;
layout(binding = 13) uniform sampler2D k12;
layout(binding = 14) uniform sampler2D k13;

void main() {
    vec2 c = vec2(0.5);
    vec4 s = texture(k0, c) + texture(k1, c) + texture(k2, c) + texture(k3, c)
           + texture(k4, c) + texture(k5, c) + texture(k6, c) + texture(k7, c)
           + texture(k8, c) + texture(k9, c) + texture(k10, c) + texture(k11, c)
           + texture(k12, c) + texture(k13, c);
    fragColor = fract(s);
}
