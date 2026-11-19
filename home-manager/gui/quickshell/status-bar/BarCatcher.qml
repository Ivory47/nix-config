import QtQuick

// While a bar panel is open (`open`), covers the whole stage so that a click anywhere else closes it
// (`dismissed()`); nothing when closed. Put it first in the stage and in the window's `mask`.
Item {
    id: root

    property bool open: false
    signal dismissed()

    width: parent.width
    height: open ? parent.height : 0

    MouseArea {
        anchors.fill: parent
        onClicked: root.dismissed()
    }
}
