import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Pipewire

PopupWindow {
    id: popup

    implicitWidth: 42
    implicitHeight: 165

    color: "transparent"
    grabFocus: true

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Rectangle {
        anchors {
            fill: parent
            margins: 6
        }
        color: "#1e1e2e"
        radius: 6

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#80000000"
            shadowBlur: 0.5
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 3
        }

        ColumnLayout {
            anchors {
                fill: parent

                topMargin: 15
                bottomMargin: 8
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
                    color: "#45475a"
                }

                Rectangle {
                    anchors.horizontalCenter: track.horizontalCenter
                    anchors.bottom: track.bottom

                    width: track.width
                    height: track.height * (Pipewire.defaultAudioSink?.audio.volume ?? 0)

                    radius: 3
                    color: "#cdd6f4"
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

                color: "#ffffff"
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
