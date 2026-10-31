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
};

layout(binding = 1) uniform sampler2D src;

const int MAX_RADIUS = 48;

void main() {
    float s = max(sigma, 0.001);
    int radius = min(int(ceil(s * 2.5)), MAX_RADIUS);
    vec4 sum = vec4(0.0);
    float weights = 0.0;
    for (int k = -MAX_RADIUS; k <= MAX_RADIUS; ++k) {
        if (abs(k) > radius)
            continue;
        float w = exp(-float(k * k) / (2.0 * s * s));
        sum += texture(src, qt_TexCoord0 + stepUv * float(k)) * w;
        weights += w;
    }
    fragColor = sum / weights;
}
