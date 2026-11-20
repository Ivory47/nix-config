pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.shared

// What the brightness / volume indicator of the bar layouts shows. `active` is true for about a
// second after a change; `kind` is "brightness" or "volume"; `value` is 0..1 (the brightness is
// on a perceptual curve); `muted` for the volume.
Singleton {
    id: root

    property bool active: false
    property string kind: "brightness"
    property real value: 0
    property bool muted: false

    readonly property real brightnessExponent: 4

    // The simple indicator (OsdBar): the bar in the middle, the icon and the number in slots at its ends.
    readonly property int slot: 20
    readonly property int slotGap: 10
    readonly property real barWidth: Theme.osdIndicatorWidth + 2 * (slot + slotGap)

    function pulse() {
        active = true
        hideTimer.restart()
    }

    // The brightness on the same curve, kept up to date (also without showing the indicator).
    property real brightness: 0
    property bool quiet: false

    function showBrightness() {
        kind = "brightness"
        quiet = false
        getBrightness.running = true
    }

    // For a slider: read it without showing the indicator.
    function readBrightness() {
        quiet = true
        getBrightness.running = true
    }

    // v is on the perceptual curve (brightnessctl -e4, as the keys use).
    function setBrightness(v) {
        brightness = Math.max(0.02, Math.min(1, v))
        Quickshell.execDetached(["brightnessctl", "-e4", "-n2", "set", Math.round(brightness * 100) + "%"])
    }

    function setVolume(v) {
        const sink = Pipewire.defaultAudioSink
        if (sink && sink.audio)
            sink.audio.volume = Math.max(0, Math.min(1, v))
    }

    Timer {
        id: hideTimer
        interval: 1200
        onTriggered: root.active = false
    }

    Process {
        id: getBrightness
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            // "device,class,current,percent%,max"
            onStreamFinished: {
                const f = text.trim().split(",")
                const cur = Number(f[2]), max = Number(f[4])
                if (max > 0) {
                    root.brightness = Math.pow(cur / max, 1 / root.brightnessExponent)
                    if (!root.quiet) {
                        root.value = root.brightness
                        root.pulse()
                    }
                }
            }
        }
    }

    // Volume: any change of the default sink's volume or mute shows it (not the first reading).
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    property bool volumeSeen: false
    readonly property real sinkVolume: Pipewire.defaultAudioSink?.audio?.volume ?? 0
    readonly property bool sinkMuted: Pipewire.defaultAudioSink?.audio?.muted ?? false

    onSinkVolumeChanged: volumeChanged()
    onSinkMutedChanged: volumeChanged()

    function volumeChanged() {
        if (!volumeSeen)
            return
        kind = "volume"
        value = Math.min(1, sinkVolume)
        muted = sinkMuted
        pulse()
    }

    Component.onCompleted: seenTimer.start()
    // The sink's first values arrive just after start: those are not changes.
    Timer {
        id: seenTimer
        interval: 1500
        onTriggered: root.volumeSeen = true
    }
}
