import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.shared

// The content of the volume menu (a vertical slider and the speaker), without a window or background of its
// own: the balanced bar puts it in its glass panel, AudioMenu.qml in a popup window.
Item {
    id: popup

    implicitWidth: 44
    implicitHeight: 165

    // The slim form (the balanced bar's panel): no margin of its own, and the same space above the slider
    // as below the speaker.
    property bool compact: false

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Item {
        anchors {
            fill: parent
            margins: popup.compact ? 0 : 6
        }

        ColumnLayout {
            anchors {
                fill: parent

                topMargin: popup.compact ? 12 : 15
                bottomMargin: popup.compact ? 6 : 8
                // leftMargin: 10
                // rightMargin: 10
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Rectangle {
                    id: track

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    width: 6
                    radius: 3
                    color: Theme.surfaceAlt
                }

                Rectangle {
                    anchors.horizontalCenter: track.horizontalCenter
                    anchors.bottom: track.bottom

                    width: track.width
                    height: track.height * (Pipewire.defaultAudioSink?.audio.volume ?? 0)

                    radius: 3
                    color: Theme.textSecondary
                }

                MouseArea {
                    anchors.fill: parent

                    onClicked: mouse => {
                        let volume = 1 - (mouse.y / height)
                        volume = Math.max(0, Math.min(1, volume))

                        Pipewire.defaultAudioSink.audio.volume = volume
                    }

                    onPositionChanged: mouse => {
                        if (pressed) {
                            let volume = 1 - (mouse.y / height)
                            volume = Math.max(0, Math.min(1, volume))

                            Pipewire.defaultAudioSink.audio.volume = volume
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter

                text: {
                    let muted = Pipewire.defaultAudioSink?.audio.muted ?? false
                    let percent = Math.round(
                        (Pipewire.defaultAudioSink?.audio.volume ?? 0) * 100
                    )

                    if (muted)
                    return " "
                    else if (percent === 0)
                    return " "
                    else if (percent <= 30)
                    return " "
                    else if (percent <= 70)
                    return " "
                    else
                    return " "
                }

                color: Theme.text
                font.pixelSize: 20

                MouseArea {
                    anchors.fill: parent

                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        Pipewire.defaultAudioSink.audio.muted =
                        !Pipewire.defaultAudioSink.audio.muted
                    }
                }
            }
        }
    }
}
