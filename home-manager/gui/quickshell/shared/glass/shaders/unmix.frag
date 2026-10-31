#version 440
// Unmixing, after Pleamar's backdrop.wgsl / backdrop_check.wgsl.
//
// The capture shows what the compositor drew: our own surface blended over the real background,
//     capture = own.rgb + (1 - own.a) * background          (own is premultiplied)
// and we kept what we presented, so the real background is
//     background = (capture - own.rgb) / (1 - own.a)
//
// mode 0: the background. rgb = background, a = 1 where it could be recovered,
//         vec4(0) where it cannot (under opaque pixels, or when the numbers are impossible).
// mode 1: a flag, 1.0 where capture and own cannot belong to the same frame, else 0.0. Its
//         mip chain's top level is the fraction of wrong pixels (see settle.frag).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float mode;
    float coverOpacity; // opacity the compositor applies to the surface (1.0 for a layer)
};

layout(binding = 1) uniform sampler2D capture;
layout(binding = 2) uniform sampler2D own;
layout(binding = 3) uniform sampler2D previous;

void main() {
    vec2 uv = qt_TexCoord0;
    vec3 f = texture(capture, uv).rgb;
    vec4 s = texture(own, uv) * coverOpacity;
    float remaining = 1.0 - s.a;

    vec4 background = vec4(0.0);
    bool wrong = false;

    if (remaining < 0.03) {
        // Opaque: the capture is only what we drew. Nothing of the background can be known,
        // but the capture must be that very frame.
        wrong = any(greaterThan(abs(f - s.rgb), vec3(0.1)));
    } else {
        vec3 bg = (f - s.rgb) / remaining;
        // 8-bit rounding in the capture is amplified by 1 / remaining.
        float margin = 0.03 + 0.5 / 255.0 / remaining;
        if (any(lessThan(bg, vec3(-margin))) || any(greaterThan(bg, vec3(1.0 + margin)))) {
            // Not a possible colour: this capture and our frame are not the same frame.
            wrong = true;
            background = texture(previous, uv);
        } else {
            background = vec4(clamp(bg, 0.0, 1.0), 1.0);
        }
    }

    if (mode > 0.5)
        fragColor = vec4(wrong ? 1.0 : 0.0, 0.0, 0.0, 1.0);
    else
        fragColor = background;
}
