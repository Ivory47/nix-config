#version 440
// Takes the unmixed draft only if the capture was the right frame (Pleamar's "settle").
//
// `flag` is 1.0 where capture and own disagree. Its mip chain's top level is the fraction of
// wrong pixels. More than one pixel in a hundred (and more than a handful, an edge's rounding)
// means the capture belongs to another frame: the previous background is kept, the glass keeps
// what it had, and the next capture will do better.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float areaPx; // pixels in the checked region
};

layout(binding = 1) uniform sampler2D draft;
layout(binding = 2) uniform sampler2D kept;
layout(binding = 3) uniform sampler2D flag;

void main() {
    float fraction = textureLod(flag, vec2(0.5), 20.0).r;
    float wrongCount = fraction * areaPx;
    bool bad = wrongCount > 16.0 && wrongCount * 100.0 > areaPx;
    fragColor = bad ? texture(kept, qt_TexCoord0) : texture(draft, qt_TexCoord0);
}
