import QtQuick

// A settled background and its frosted version.
//
// Two of these take turns (GlassBackdrop ping-pongs): one is shown while the other is rebuilt
// from the newest capture, so that nothing that is being updated is ever read by what is drawn
// in the same frame. (Pleamar does the same with its two background textures.)
//
// All the items here are offscreen, one texel per pixel, and sized in real pixels.
Item {
    id: root

    // The unmixed draft of the newest capture, and the "wrong frame" flag (with mip levels).
    required property Item draft
    required property Item flag
    // The other bundle's background: what to keep when the capture turns out to be wrong.
    required property Item kept
    required property size sizePx
    // Gaussian sigma of the blur, in real pixels.
    required property real sigma

    readonly property Item bg: bgSource
    readonly property Item frosted: blurV

    function update() {
        bgSource.scheduleUpdate();
        blurH.scheduleUpdate();
        blurV.scheduleUpdate();
    }

    // Blur the background it holds again, with the current sigma (the radius was changed): the
    // blur passes only, from the settled background, which stays as it is. (Without this the
    // textures are only rendered when a capture arrives, so a new radius would show only when
    // the screen behind changes.)
    function reblur() {
        blurH.scheduleUpdate();
        blurV.scheduleUpdate();
    }

    // draft, or the previous background if the check says the capture was the wrong frame
    ShaderEffect {
        id: settleFx
        width: root.sizePx.width
        height: root.sizePx.height
        visible: false
        blending: false

        property variant draft: root.draft
        property variant kept: root.kept
        property variant flag: root.flag
        property real areaPx: root.sizePx.width * root.sizePx.height

        fragmentShader: Qt.resolvedUrl("shaders/settle.frag.qsb")
    }

    ShaderEffectSource {
        id: bgSource
        sourceItem: settleFx
        live: false
        visible: false
        textureSize: root.sizePx
    }

    // Wide pass: full size background -> half size.
    ShaderEffect {
        id: blurHFx
        width: Math.max(1, Math.round(root.sizePx.width / 2))
        height: Math.max(1, Math.round(root.sizePx.height / 2))
        visible: false
        blending: false

        property variant src: bgSource
        property vector2d stepUv: Qt.vector2d(1 / root.sizePx.width, 0)
        property real sigma: root.sigma

        fragmentShader: Qt.resolvedUrl("shaders/blur.frag.qsb")
    }

    ShaderEffectSource {
        id: blurH
        sourceItem: blurHFx
        live: false
        visible: false
        format: ShaderEffectSource.RGBA16F
        textureSize: Qt.size(blurHFx.width, blurHFx.height)
    }

    // Tall pass: half size -> half size.
    ShaderEffect {
        id: blurVFx
        width: blurHFx.width
        height: blurHFx.height
        visible: false
        blending: false

        property variant src: blurH
        property vector2d stepUv: Qt.vector2d(0, 1 / blurHFx.height)
        property real sigma: root.sigma / 2

        fragmentShader: Qt.resolvedUrl("shaders/blur.frag.qsb")
    }

    ShaderEffectSource {
        id: blurV
        sourceItem: blurVFx
        live: false
        visible: false
        format: ShaderEffectSource.RGBA16F
        textureSize: Qt.size(blurHFx.width, blurHFx.height)
    }
}
