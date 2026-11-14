#version 440
// One pass of a separable gaussian blur over premultiplied RGBA (so unknown pixels, which are
// vec4(0), simply carry no weight once the result is divided by its alpha when sampled).
// Used twice: horizontal into a half size texture, then vertical. After Pleamar's blur.rs.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 stepUv;  // distance between two source texels, in uv, along the blur axis
    float sigma;  // in source texels
    float maxTaps; // most samples per side (cost); a wider blur spreads them out instead
};

layout(binding = 1) uniform sampler2D src;

const int MAX_RADIUS = 48;

void main() {
    float s = max(sigma, 0.001);
    // The blur reaches 2.5 sigma. With more texels than `maxTaps` it takes every n-th one (the
    // texture's linear filtering fills the gaps), so the cost is capped and the blur stays as wide.
    float reach = ceil(s * 2.5);
    int taps = int(clamp(maxTaps, 1.0, float(MAX_RADIUS)));
    int n = int(min(reach, float(taps)));
    float stride = reach / float(max(n, 1));
    vec4 sum = vec4(0.0);
    float weights = 0.0;
    for (int k = -n; k <= n; ++k) {
        float off = float(k) * stride;
        float w = exp(-off * off / (2.0 * s * s));
        sum += texture(src, qt_TexCoord0 + stepUv * off) * w;
        weights += w;
    }
    fragColor = sum / weights;
}
