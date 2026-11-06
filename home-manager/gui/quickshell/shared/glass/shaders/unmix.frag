#version 440
// Unmixing, after Pleamar's backdrop.wgsl / backdrop_check.wgsl.
//
// The capture shows what the compositor drew: our own surface blended over the real background,
//     capture = own.rgb + (1 - own.a) * background          (own is premultiplied)
// and we kept what we presented, so the real background is
//     background = (capture - own.rgb) / (1 - own.a)
//
// Which of the frames we presented is the one in the capture? The compositor may answer with the
// bar as it was a frame or two earlier, and the glass changes with every update, so the wrong
// `own` gives colours that are in range but wrong. Every presented version of the surface is
// kept (own0..own7, a ring), and one opaque pixel at the top left of the surface (GlassTag.qml)
// says which: its blue channel is 46 + 4 * (version % 8), red and green 30. The compositor
// copies opaque pixels exactly, so the capture holds the version of the frame it was made from.
// If the pixel is not one of ours, or its version was never kept, the capture is the wrong frame.
// Every instance has its own red (tagRed), so that the bar's tag, which shows through where a
// popup is not on screen, is not taken for a version of the popup's. A popup sets absentRed to the
// bar's red: that tag means its surface was not in the frame, and the capture is the background
// as it is (a rejected capture would keep a stale background).
//
// mode 0: the background. rgb = background, a = 1 where it could be recovered,
//         vec4(0) where it cannot (under opaque pixels, or when the numbers are impossible).
// mode 1: statistics, one texel per pixel, to be averaged by the mip chain:
//         r = 1 where capture and own cannot belong to the same frame,
//         g = 1 where the background is unknown in this draft (alpha 0),
//         b = 1 where the numbers were impossible (the capture is not of our frame),
//         a = 1.
//         The top level of the mip chain holds the fractions (see settle.frag, verdict.frag).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float mode;
    float coverOpacity; // opacity the compositor applies to the surface (1.0 for a layer)
    vec2 capOrigin;     // where our region is inside the capture (uv): the capture may be of the
    vec2 capScale;      // whole output, and is cropped here
    float forceBad;     // for tests: treat every capture as the wrong frame
    vec2 texPx;         // size of the cropped capture in pixels
    float tagMask;      // bit i set: ring slot i holds a version that was presented
    float tagRed;       // red channel of this instance's tag (the bar 30, the popups 34 / 38)
    float absentRed;    // red channel of a tag that means "our surface is not in this frame" (the
                        // bar's, for the popups): the capture is then the background as it is.
                        // 0: off (the bar: a frame that does not hold our tag is rejected)
};

layout(binding = 1) uniform sampler2D capture;
layout(binding = 2) uniform sampler2D own0;
layout(binding = 3) uniform sampler2D own1;
layout(binding = 4) uniform sampler2D own2;
layout(binding = 5) uniform sampler2D own3;
layout(binding = 6) uniform sampler2D own4;
layout(binding = 7) uniform sampler2D own5;
layout(binding = 8) uniform sampler2D own6;
layout(binding = 9) uniform sampler2D own7;
layout(binding = 10) uniform sampler2D previous;

vec4 ownAt(int i, vec2 uv) {
    if (i == 0) return texture(own0, uv);
    if (i == 1) return texture(own1, uv);
    if (i == 2) return texture(own2, uv);
    if (i == 3) return texture(own3, uv);
    if (i == 4) return texture(own4, uv);
    if (i == 5) return texture(own5, uv);
    if (i == 6) return texture(own6, uv);
    return texture(own7, uv);
}

void main() {
    vec2 uv = qt_TexCoord0;

    // The version of the frame this capture was made from, from the tag pixel (the centre of
    // the first pixel of the region).
    vec2 tagUv = vec2(0.5) / texPx;
    vec3 tag = texture(capture, capOrigin + tagUv * capScale).rgb * 255.0;
    int version = int(floor((tag.b - 46.0) / 4.0 + 0.5));
    bool shape = version >= 0 && version < 8
              && abs(tag.b - (46.0 + 4.0 * float(version))) < 1.5
              && abs(tag.g - 30.0) < 1.5;
    bool tagOk = shape && abs(tag.r - tagRed) < 1.5
              && ((int(tagMask + 0.5) >> version) & 1) == 1;
    // Another instance's tag (the bar's) shows where our surface would be: it is opaque there
    // whenever it is in the frame, so it was not. Nothing of ours to remove.
    bool absent = absentRed > 0.5 && shape && abs(tag.r - absentRed) < 1.5;

    vec3 f = texture(capture, capOrigin + uv * capScale).rgb;
    vec4 s = tagOk ? ownAt(version, uv) * coverOpacity : vec4(0.0);
    float remaining = 1.0 - s.a;

    vec4 background = vec4(0.0);
    bool wrong = !tagOk && !absent;
    bool impossible = false;

    if (absent) {
        // The capture is the background: this is how a popup that is closed or just opening
        // gets a fresh one without being on screen.
        background = vec4(f, 1.0);
    } else if (!tagOk) {
        // Not a frame we know: nothing to unmix against. The whole capture is rejected.
        background = texture(previous, uv);
    } else if (remaining < 0.03) {
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
            impossible = true;
            background = texture(previous, uv);
        } else {
            background = vec4(clamp(bg, 0.0, 1.0), 1.0);
        }
    }

    if (forceBad > 0.5)
        wrong = true;

    if (mode > 0.5)
        fragColor = vec4(wrong ? 1.0 : 0.0, background.a < 0.5 ? 1.0 : 0.0, impossible ? 1.0 : 0.0, 1.0);
    else
        fragColor = background;
}
