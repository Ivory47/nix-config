import QtQuick
import Quickshell
import Quickshell.Io

OSD {
    id: osd

    contentHorizontalAlignment: Qt.AlignHCenter
    contentVerticalAlignment: Qt.AlignTop
    contentMargin: 1

    fadeInDuration: 0
    fadeOutDuration: 200
    hideDelay: 800

    Rectangle {
        id: background

        property int horizontalPadding: Theme.spacingMedium
        property int verticalPadding: Theme.spacingMedium

        width: row.implicitWidth + horizontalPadding * 2
        height: Theme.statusBarHeight

        color: Theme.background
        radius: Theme.radiusMedium

        Row {
            id: row

            anchors.centerIn: parent
            spacing: Theme.spacingMedium

            Text {
                text: "󰃞"
                color: Theme.text
                font.pixelSize: Theme.textSmall
            }

            Rectangle {
                id: indicator

                anchors.verticalCenter: parent.verticalCenter

                width: Theme.osdIndicatorWidth
                height: background.height - background.verticalPadding * 2
                // height: 11

                radius: height / 2
                color: Theme.surfaceAlt

                Rectangle {
                    width: parent.width * osd.brightness
                    height: parent.height
                    radius: height / 2
                    color: Theme.accent
                }
            }

            Text {
                text: "󰃠"
                color: Theme.text
                font.pixelSize: Theme.textSmall
            }
        }
    }

    property real brightness: 0
    property real brightnessExponent: 4

    function updateBrightness() {
        getBrightness.running = true
        osd.show()
    }


    Process {
        id: getBrightness

        command: ["brightnessctl", "get"]

        stdout: StdioCollector {
            onStreamFinished: {
                let current = Number(text.trim())


                getMaxBrightness.current = current
                getMaxBrightness.running = true
            }
        }
    }

    Process {
        id: getMaxBrightness

        property real current: 0

        command: ["brightnessctl", "max"]

        stdout: StdioCollector {
            onStreamFinished: {
                let maximum = Number(text.trim())

                if (maximum > 0) {
                    let hardwareFraction = getMaxBrightness.current / maximum

                    osd.brightness = Math.pow(
                        hardwareFraction,
                        1 / osd.brightnessExponent
                    )

                    osd.show()
                }
            }
        }
    }

}
