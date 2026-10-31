#version 440
// The glass itself, after Pleamar's shape.wgsl (lens branch), for a rectangle whose chosen
// edges are bevelled like the rim of a thick piece of glass.
//
// Inputs are the two textures of the backdrop: `sharp` (the real background behind the surface,
// recovered by unmixing; alpha 0 where unknown) and `frosted` (the same, blurred, premultiplied).
//
// The result is drawn with alpha `alpha` (< 1, Pleamar's LENS_ALPHA = 0.88), because the next
// capture can only be unmixed where the surface lets some of the background through. What
// leaks through is known, so it is subtracted beforehand: what you see is the glass alone.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 sizePx;      // size of this panel, real pixels
    vec2 originPx;    // its top left inside the backdrop, real pixels
    vec2 backdropPx;  // size of the backdrop, real pixels
    vec4 edges;       // 1.0 where the edge is bevelled: left, top, right, bottom
    vec4 tint;        // rgb + strength
    vec2 lightDir;    // direction the light comes from (screen space, y down)
    float pxRatio;      // real pixels per logical pixel
    float known;      // 1.0 once a backdrop exists
    float cornerRadius; // logical
    float bevel;        // logical, width of the curved rim
    float thickness;    // height of the rim relative to its width
    float refraction;   // strength of the bending
    float ior;
    float dispersion;
    float frost;        // 0 = sharp backdrop, 1 = fully frosted
    float brightness;
    float contrast;
    float saturation;
    float shine;
    float alpha;
    float glassOpacity;
    float debugView;    // 0 off, 1 sharp backdrop, 2 frosted backdrop
};

layout(binding = 1) uniform sampler2D sharp;
layout(binding = 2) uniform sampler2D frosted;

vec2 backdropUv(vec2 px) {
    return clamp(px, vec2(0.5), backdropPx - vec2(0.5)) / backdropPx;
}

// Frosted colour at a place, or vec3(-1) where nothing is known.
vec3 frostedAt(vec2 px) {
    vec4 f = texture(frosted, backdropUv(px));
    return f.a > 0.002 ? f.rgb / f.a : vec3(-1.0);
}

// What is really behind: the sharp colour where it was recovered, the frosted one elsewhere.
vec3 trueAt(vec2 px, vec3 fallback) {
    vec3 fr = frostedAt(px);
    if (fr.r < 0.0) fr = fallback;
    vec4 s = texture(sharp, backdropUv(px));
    return s.a > 0.5 ? s.rgb : fr;
}

vec3 seenAt(vec2 px, vec3 fallback) {
    vec3 fr = frostedAt(px);
    if (fr.r < 0.0) fr = fallback;
    return mix(trueAt(px, fallback), fr, frost);
}

// Where the ray that reaches this pixel came from, relative to the pixel, for one index.
vec2 bendFor(float index, vec3 N, float depthPx) {
    vec3 r = refract(vec3(0.0, 0.0, -1.0), N, 1.0 / max(index, 1.001));
    return r.xy / max(-r.z, 0.25) * depthPx;
}

void main() {
    vec2 p = qt_TexCoord0 * sizePx;
    vec2 base = originPx + p;

    if (debugView > 0.5 && debugView < 1.5) {
        vec4 s = texture(sharp, backdropUv(base));
        fragColor = vec4(s.a > 0.5 ? s.rgb : vec3(1.0, 0.0, 1.0), 1.0);
        return;
    }
    if (debugView >= 1.5) {
        vec3 fr = frostedAt(base);
        fragColor = vec4(fr.r < 0.0 ? vec3(1.0, 0.0, 1.0) : fr, 1.0);
        return;
    }

    float b = max(bevel * pxRatio, 1.0);

    // Distance to the nearest bevelled edge, and which way is out there.
    float inside = 1.0e5;
    vec2 n = vec2(0.0, 1.0);
    if (edges.x > 0.5 && p.x < inside) { inside = p.x; n = vec2(-1.0, 0.0); }
    if (edges.y > 0.5 && p.y < inside) { inside = p.y; n = vec2(0.0, -1.0); }
    if (edges.z > 0.5 && sizePx.x - p.x < inside) { inside = sizePx.x - p.x; n = vec2(1.0, 0.0); }
    if (edges.w > 0.5 && sizePx.y - p.y < inside) { inside = sizePx.y - p.y; n = vec2(0.0, 1.0); }

    // Coverage (rounded corners).
    float r = cornerRadius * pxRatio;
    vec2 halfSize = sizePx * 0.5;
    vec2 q = abs(p - halfSize) - (halfSize - vec2(r));
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
    float coverage = clamp(0.5 - d, 0.0, 1.0);

    // The rim: a quarter circle from the edge (t = 0) to the flat middle (t = 1).
    float t = clamp(inside / b, 0.0, 1.0);
    float u = 1.0 - t;
    float z = sqrt(max(1.0 - u * u, 0.0));
    float slope = t < 1.0 ? min(u / max(z, 0.05), 6.0) : 0.0;
    vec3 N = normalize(vec3(n * slope, 1.0));
    float depthPx = thickness * b * z * refraction;

    vec3 mid = vec3(0.5);
    vec3 col;
    col.r = seenAt(base + bendFor(ior - dispersion, N, depthPx), mid).r;
    col.g = seenAt(base + bendFor(ior, N, depthPx), mid).g;
    col.b = seenAt(base + bendFor(ior + dispersion, N, depthPx), mid).b;

    // Tone.
    col = (col - 0.5) * contrast + 0.5 + brightness;
    float luma = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(luma), col, saturation);
    col = mix(col, tint.rgb, tint.a);

    // Light on the rim.
    float rim = 1.0 - smoothstep(0.3 * pxRatio, 3.0 * pxRatio, inside);
    float edgeLine = 1.0 - smoothstep(0.0, 1.5 * pxRatio, inside);
    vec2 L = normalize(lightDir);
    float facing = max(dot(n, L), 0.0);
    float away = max(dot(n, -L), 0.0);
    float fresnel = pow(u, 3.0) * 0.5;
    col += vec3(shine * (0.65 * edgeLine * facing + 0.28 * rim * away + fresnel * 0.35));
    col = clamp(col, 0.0, 1.0);

    float seen = coverage * glassOpacity;
    float a = alpha * seen;

    if (known < 0.5) {
        // No backdrop yet: a plain tinted surface that already lets the background through,
        // so that the first capture can be unmixed.
        vec3 plain = mix(mid, tint.rgb, max(tint.a, 0.6));
        fragColor = vec4(plain * a, a) * qt_Opacity;
        return;
    }

    vec3 underneath = trueAt(base, mid);
    vec3 rgb = clamp(seen * (col - (1.0 - alpha) * underneath), vec3(0.0), vec3(a));
    fragColor = vec4(rgb, a) * qt_Opacity;
}
