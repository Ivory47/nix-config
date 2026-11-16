#version 440
// A soft drop shadow for a rounded rectangle, drawn only OUTSIDE that rectangle (the glass
// itself must have nothing under it: where the stack lets less than about 3% of the background
// through, the background cannot be recovered from the capture). All sizes in logical pixels.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;  // this item: the panel plus `margin` on every side
    vec2 offset;    // how far the shadow is moved from the panel (x right, y down)
    vec4 color;     // rgb, and the opacity at the strongest point
    float margin;
    float radius;   // corner radius of the panel
    float blur;     // distance over which the shadow fades out
};

// Distance to a rounded box centred on the origin: negative inside.
float roundedBox(vec2 p, vec2 hs, float r) {
    vec2 q = abs(p) - hs + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 p = qt_TexCoord0 * itemSize - itemSize * 0.5;
    vec2 hs = itemSize * 0.5 - margin;
    float r = min(radius, min(hs.x, hs.y));

    float outside = roundedBox(p, hs, r);          // > 0 outside the panel
    float cut = smoothstep(0.0, 1.0, outside);       // nothing under the panel itself

    float d = roundedBox(p - offset, hs, r);       // the moved copy
    float t = clamp(1.0 - (d + blur * 0.5) / blur, 0.0, 1.0);
    float a = t * t * (3.0 - 2.0 * t) * color.a * cut;

    fragColor = vec4(color.rgb * a, a) * qt_Opacity;
}
