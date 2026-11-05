#version 440
// Counts what settle.frag decided, on the GPU, without reading anything back per capture.
//
// The accumulator is a 3x1 float texture that this pass reads (the item is `recursive`: it samples
// its own previous contents) and writes, once per update of the pipeline. Its 12 numbers:
//   texel 0: accepted, rejected as the wrong frame, rejected as unusable, valid background seen (0/1)
//   texel 1: sum of the unknown fraction, sum of the wrong fraction, last unknown, last wrong
//   texel 2: rejected while no valid background existed yet (the glass is on its plain tint),
//            rejected while the last valid one was kept, sum of the impossible fraction, last one
// readout.frag turns them into bytes, for the occasional asynchronous read.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float areaPx;
};

layout(binding = 1) uniform sampler2D flag;
layout(binding = 2) uniform sampler2D acc;

void main() {
    vec4 s = textureLod(flag, vec2(0.5), 20.0);
    float wrongCount = s.r * areaPx;
    bool wrongFrame = wrongCount > 16.0 && wrongCount * 100.0 > areaPx;
    bool unusable = s.g > 0.6;
    bool bad = wrongFrame || unusable;

    int t = int(floor(qt_TexCoord0.x * 3.0));
    vec4 prev = texture(acc, vec2((float(t) + 0.5) / 3.0, 0.5));
    float validSeen = texture(acc, vec2(0.5 / 3.0, 0.5)).w;

    vec4 result = prev;
    if (t == 0) {
        result.x += bad ? 0.0 : 1.0;
        result.y += wrongFrame ? 1.0 : 0.0;
        result.z += (!wrongFrame && unusable) ? 1.0 : 0.0;
        result.w = max(prev.w, bad ? 0.0 : 1.0);
    } else if (t == 1) {
        result.x += s.g;
        result.y += s.r;
        result.z = s.g;
        result.w = s.r;
    } else {
        result.x += (bad && validSeen < 0.5) ? 1.0 : 0.0;
        result.y += (bad && validSeen > 0.5) ? 1.0 : 0.0;
        result.z += s.b;
        result.w = s.b;
    }
    fragColor = result;
}
