import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs.shared
import qs.shared.glass
import Glass.Native

// One notification, as a card in the Column of NotificationPopups. The item itself is the card's
// slot in the column (its height is the card's height times `collapse`, so the cards below slide up
// as one comes and goes); `body` is the card, which slides in from the right and fades with `appear`.
//
// Timing: the card closes itself after `seconds` (the notification's own timeout, else Theme's; a
// critical one stays), paused while the mouse is over it. A click runs the "default" action if
// there is one and closes the notification otherwise. The Notification object is kept alive by a
// RetainableLock until the card has faded out, so the card can still show it while it goes.
//
// The glass is in `glassParent` (the window's top item), not in the card: the plugin takes a
// glass's region from the item's own position and size and only hears of changes to those, so the
// glass has its x, y, width and height bound to what the card draws (see WallpaperOverlay.qml, the
// same reason).
Item {
    id: card

    required property var notification
    // The window's top item and the Column this card is in (their positions give the glass's).
    required property Item glassParent
    required property Item listItem
    // Whether it is this card's turn to be shown (the newest `maxShown` are).
    property bool slot: false
    signal finished()

    readonly property var n: notification
    readonly property bool critical: !!n && n.urgency === NotificationUrgency.Critical
    readonly property bool hasText: !!n && n.body.length > 0
    readonly property var buttons: {
        const out = []
        if (!n)
            return out
        for (const a of n.actions)
            if (a.identifier !== "default")
                out.push(a)
        return out
    }
    // How long it stays, in seconds; 0 = until it is closed by hand.
    readonly property real seconds: {
        if (!n || critical)
            return 0
        // (Quickshell's docs say seconds; the value is what the sender gave, in milliseconds.)
        if (n.expireTimeout > 0)
            return n.expireTimeout / 1000
        const base = Theme.notificationTimeout
        return buttons.length > 0 ? base * 1.6 : base
    }
    readonly property bool hovered: hover.hovered

    property bool entered: false
    property bool leaving: false
    property real appear: 0      // the card's fade and slide, 0..1
    property real collapse: 0    // the slot's height, 0..1
    property real elapsed: 0     // ms shown (not counting the time the mouse was over it)
    readonly property real progress: seconds > 0 ? Math.max(0, 1 - elapsed / (seconds * 1000)) : 1
    readonly property date created: new Date()
    readonly property int pad: 14
    readonly property int gap: Theme.spacingSmall + 2

    visible: slot || leaving
    clip: true
    height: visible ? (body.height + gap) * collapse : 0

    // Closing never waits for the animation of one that never showed.
    function startLeave() {
        if (leaving)
            return
        leaving = true
        enterAnim.stop()
        if (entered)
            leaveAnim.start()
        else
            finish()
    }

    function finish() {
        lock.locked = false
        card.finished()
    }

    function activate() {
        if (!n)
            return
        for (const a of n.actions) {
            if (a.identifier === "default") {
                invoke(a)
                return
            }
        }
        n.dismiss()
    }

    // An action closes the notification unless it is "resident".
    function invoke(a) {
        a.invoke()
        if (!leaving && n && !n.resident)
            n.dismiss()
    }

    function enter() {
        if (entered || leaving)
            return
        entered = true
        enterAnim.start()
    }

    onSlotChanged: if (slot) enter()
    Component.onCompleted: if (slot) enter()

    RetainableLock {
        id: lock
        object: card.n
        locked: true
    }

    Connections {
        target: card.n
        function onClosed() { card.startLeave() }
        // A notification that replaces this one (same id) starts its time again.
        function onSummaryChanged() { card.elapsed = 0 }
        function onBodyChanged() { card.elapsed = 0 }
    }

    FrameAnimation {
        running: card.entered && card.slot && !card.leaving && !card.hovered && card.seconds > 0
        onTriggered: {
            card.elapsed += frameTime * 1000
            if (card.elapsed >= card.seconds * 1000 && card.n)
                card.n.expire()
        }
    }

    ParallelAnimation {
        id: enterAnim
        NumberAnimation { target: card; property: "appear"; to: 1; duration: 240; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "collapse"; to: 1; duration: 200; easing.type: Easing.OutCubic }
    }

    SequentialAnimation {
        id: leaveAnim
        NumberAnimation { target: card; property: "appear"; to: 0; duration: 160; easing.type: Easing.InCubic }
        NumberAnimation { target: card; property: "collapse"; to: 0; duration: 140; easing.type: Easing.InOutCubic }
        ScriptAction { script: card.finish() }
    }

    // The glass, drawn by the compositor under the whole window; it follows what the card draws.
    LucentGlassPanel {
        id: glass
        readonly property bool wanted: Theme.glass && Theme.compositorGlass && available
        parent: card.glassParent
        x: card.listItem.x + card.x + body.x
        y: card.listItem.y + card.y
        width: Math.max(0, body.width - body.x)
        height: Math.max(0, Math.min(body.height, card.height))
        active: wanted && card.visible && width > 8 && height > 8
        glassOpacity: card.appear
        blurRadius: Theme.glassBlurRadius
        maxTaps: Math.round(Math.max(4, Theme.blurMaxTaps * Math.pow(Math.min(1, 14 / Math.max(0.1, blurRadius)), Theme.blurTapsFalloff)))
        style: PanelGlassStyle {
            cornerRadius: Theme.radiusLarge
            edges: Qt.vector4d(1, 1, 1, 1)
            tint: Theme.background
        }
    }

    Item {
        id: body
        width: card.width
        height: Math.max(content.height, 40) + 2 * card.pad
        x: (1 - card.appear) * 40
        opacity: card.appear

        HoverHandler {
            id: hover
        }

        // No compositor glass (no plugin, or switched off): an opaque panel.
        Rectangle {
            anchors.fill: parent
            visible: !glass.wanted
            radius: Theme.radiusLarge
            color: Theme.background
        }

        // The border: like the bar's, red and a little thicker for a critical notification.
        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusLarge
            color: "transparent"
            border.width: card.critical ? 2 : 1
            border.color: card.critical ? Theme.red
                : Qt.rgba(Theme.barBorderColor.r, Theme.barBorderColor.g, Theme.barBorderColor.b, Theme.barBorderOpacity)
        }

        // A click anywhere on the card; the buttons below take their own.
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: card.activate()
        }

        // The picture the sender gave, else its icon, else a bell on a tile.
        ClippingRectangle {
            x: card.pad
            y: card.pad
            width: 40
            height: 40
            radius: card.n && card.n.image ? Theme.radiusMedium : (iconImage.source == "" ? Theme.radiusMedium : 0)
            color: iconImage.source == "" ? Theme.surface : "transparent"

            Image {
                id: iconImage
                anchors.fill: parent
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                sourceSize.width: 96
                sourceSize.height: 96
                source: {
                    if (!card.n)
                        return ""
                    const img = card.n.image
                    if (img)
                        return img.startsWith("/") ? "file://" + img : img
                    const ic = card.n.appIcon
                    if (ic.startsWith("/"))
                        return "file://" + ic
                    return ic ? Quickshell.iconPath(ic, true) : ""
                }
            }

            Text {
                anchors.centerIn: parent
                visible: iconImage.source == ""
                text: "\uDB80\uDC9A"
                color: Theme.accent
                font.pixelSize: Theme.textLarge + 2
            }
        }

        Column {
            id: content
            x: card.pad + 40 + Theme.spacingMedium
            y: card.pad
            width: body.width - x - card.pad
            spacing: 3

            // App name; the time, or the close button while the mouse is over the card.
            Item {
                width: parent.width
                height: 20

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.rightMargin: 40
                    anchors.verticalCenter: parent.verticalCenter
                    text: card.n ? card.n.appName : ""
                    color: Theme.textMuted
                    font.pixelSize: Theme.textSmall
                    elide: Text.ElideRight
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !card.hovered
                    text: Qt.formatDateTime(card.created, "HH:mm")
                    color: Theme.textMuted
                    font.pixelSize: Theme.textSmall
                }

                Rectangle {
                    id: closeButton
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: card.hovered
                    width: 20
                    height: 20
                    radius: 10
                    color: closeArea.containsMouse ? Theme.surfaceAlt : Theme.surface

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: Theme.text
                        font.pixelSize: Theme.textMedium
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.n.dismiss()
                    }
                }
            }

            Text {
                width: parent.width
                text: card.n ? card.n.summary : ""
                visible: text.length > 0
                color: Theme.text
                font.pixelSize: Theme.textMedium
                font.bold: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }

            Text {
                width: parent.width
                visible: card.hasText
                text: card.n ? card.n.body : ""
                color: Theme.textSecondary
                font.pixelSize: Theme.textSmall + 1
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                textFormat: Text.StyledText
            }

            Flow {
                width: parent.width
                topPadding: card.buttons.length > 0 ? 6 : 0
                spacing: Theme.spacingSmall
                visible: card.buttons.length > 0

                Repeater {
                    model: card.buttons

                    Rectangle {
                        id: chip
                        required property var modelData
                        width: chipLabel.implicitWidth + 24
                        height: 26
                        radius: Theme.radiusMedium
                        color: chipArea.containsMouse ? Theme.surface : "transparent"
                        border.width: 1
                        border.color: Theme.surfaceAlt

                        CenteredText {
                            id: chipLabel
                            anchors.centerIn: parent
                            text: chip.modelData.text
                            color: Theme.text
                            font.pixelSize: Theme.textSmall
                        }

                        MouseArea {
                            id: chipArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: card.invoke(chip.modelData)
                        }
                    }
                }
            }
        }

        // How much time is left (not for one that stays).
        Rectangle {
            visible: card.seconds > 0
            x: Theme.radiusLarge
            y: body.height - 3
            width: (body.width - 2 * Theme.radiusLarge) * card.progress
            height: 2
            radius: 1
            color: Theme.accent
            opacity: 0.7
        }
    }
}
