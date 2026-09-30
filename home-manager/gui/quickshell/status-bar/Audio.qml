import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Item {
    id: audio

    implicitWidth: audioText.implicitWidth
    implicitHeight: audioText.implicitHeight

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Text {
        id: audioText

        property real audioLevel: Pipewire.defaultAudioSink?.audio.volume ?? 0
        property bool muted: Pipewire.defaultAudioSink?.audio.muted ?? false

        text: {
            let percent = Math.round(audioLevel * 100)

            if (muted)
            return "  " + percent
            else if (percent === 0)
            return "  0"
            else if (percent <= 30)
            return "  " + percent
            else if (percent <= 70)
            return "  " + percent
            else
            return "  " + percent
        }

        color: {
            let percent = audioLevel * 100

            if (muted || audioLevel == 0)
            return Theme.textMuted
            else
            return Theme.text
        }

        font.pixelSize: 14
    }

    MouseArea {
        anchors.fill: parent

        cursorShape: Qt.PointingHandCursor

        onWheel: event => {
            let step = 0.05
            let volume = Pipewire.defaultAudioSink.audio.volume

            if (event.angleDelta.y > 0)
                volume += step
            else if (event.angleDelta.y < 0)
                volume -= step

            Pipewire.defaultAudioSink.audio.volume = Math.max(0, Math.min(volume, 1))

        }

        onClicked: {
            audioMenu.visible = !audioMenu.visible
        }
    }

    AudioMenu {
        id: audioMenu

        visible: false

        anchor.item: audio
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.margins.top: 24
    }
}
