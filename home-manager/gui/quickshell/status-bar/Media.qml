import QtQuick
import Quickshell.Services.Mpris
import qs.shared

// What is playing (MPRIS): "󰎆 title – artist"; click pauses or resumes. Hidden when no player plays.
Item {
    id: root

    property int maxWidth: 260
    readonly property var player: {
        const list = Mpris.players.values
        return list.find(p => p.isPlaying) ?? list.find(p => p.playbackState === MprisPlaybackState.Paused) ?? null
    }
    readonly property string text: !player ? "" : (player.trackTitle + (player.trackArtist ? " – " + player.trackArtist : ""))

    visible: !!player && player.isPlaying
    implicitWidth: visible ? Math.min(maxWidth, label.implicitWidth) : 0
    implicitHeight: label.implicitHeight

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        width: root.maxWidth
        text: "󰎆  " + root.text
        elide: Text.ElideRight
        color: Theme.text
        font.pixelSize: 13
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.player) root.player.togglePlaying()
    }
}
