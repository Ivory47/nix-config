#version 440
// Turns the accumulator of verdict.frag into bytes, so that it can be read back with
// grabToImage() (8 bits per channel) every now and then: pixel i holds number i as a whole number
// in red (low byte), green and blue (high bytes). Fractions are scaled first, see `scale`.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
};

layout(binding = 1) uniform sampler2D acc;

void main() {
    int i = int(floor(qt_TexCoord0.x * 12.0));
    int t = i / 4;
    int c = i - t * 4;
    vec4 v4 = texture(acc, vec2((float(t) + 0.5) / 3.0, 0.5));
    float v = c == 0 ? v4.x : (c == 1 ? v4.y : (c == 2 ? v4.z : v4.w));

    float scale = 1.0;
    if (i == 4 || i == 5 || i == 10) scale = 1000.0;
    if (i == 6 || i == 7 || i == 11) scale = 10000.0;

    float n = floor(v * scale + 0.5);
    float b0 = mod(n, 256.0);
    float b1 = mod(floor(n / 256.0), 256.0);
    float b2 = min(floor(n / 65536.0), 255.0);
    fragColor = vec4(b0, b1, b2, 255.0) / 255.0;
}
