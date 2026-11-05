#version 440
// Takes the unmixed draft of a capture only if it is good (Pleamar's "settle"); otherwise the
// previous background is kept, and the glass keeps what it had.
//
// `flag` holds statistics per pixel (see unmix.frag, mode 1); its mip chain's top level is the
// average, so its texel is the fraction of pixels for each statistic.
//
// A capture is rejected when
//   - it belongs to another frame: more than one pixel in a hundred (and more than a handful, an
//     edge's rounding) cannot be that frame's, or
//   - it is unusable: more than 60% of the draft's background is unknown.
// verdict.frag makes the same decision, to count it.
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
    vec4 stats = textureLod(flag, vec2(0.5), 20.0);
    float wrongCount = stats.r * areaPx;
    bool wrongFrame = wrongCount > 16.0 && wrongCount * 100.0 > areaPx;
    bool unusable = stats.g > 0.6;
    bool bad = wrongFrame || unusable;
    fragColor = bad ? texture(kept, qt_TexCoord0) : texture(draft, qt_TexCoord0);
}
