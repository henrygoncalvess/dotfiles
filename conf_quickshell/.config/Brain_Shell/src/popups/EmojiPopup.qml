import QtQuick
import Quickshell
import Quickshell.Wayland
import "../shapes"
import "../"

// Bottom-right emoji picker, opened with SUPER + PERIOD (see bindings.conf →
// ipc call emoji-toggle). Same window shape, slide and focus handling as
// ClipboardPopup so both bottom-right panels feel identical.

PanelWindow {
    id: root

    readonly property int popupWidth:  420
    readonly property int popupHeight: 520
    readonly property int fw: Theme.cornerRadius
    readonly property int fh: Theme.cornerRadius

    anchors.right:  true
    anchors.bottom: true

    implicitWidth:  popupWidth  + fw
    implicitHeight: popupHeight + fh

    exclusionMode: ExclusionMode.Ignore
    color:         "transparent"

    WlrLayershell.layer:         WlrLayer.Overlay
    property bool wantsFocus: false
    WlrLayershell.keyboardFocus: wantsFocus ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Timer {
        id: focusGrabTimer
        interval: 15
        onTriggered: if (windowVisible && Popups.emojiOpen) root.wantsFocus = true
    }

    mask: Region { item: maskProxy }
    Item {
        id: maskProxy
        x:      root.implicitWidth  - sizer.width
        y:      root.implicitHeight - sizer.height
        width:  sizer.width
        height: sizer.height
    }

    // Screen this copy belongs to (PopupLayer is instantiated per screen).
    // Without `screen` the copies stack on one monitor and the top one
    // swallows every click.
    property var popupScreen: null
    screen: popupScreen

    property bool windowVisible: false
    visible: windowVisible && Popups.isActiveScreen(popupScreen)

    Connections {
        target: Popups
        function onEmojiOpenChanged() {
            if (Popups.emojiOpen) {
                closeTimer.stop()
                root.windowVisible = true
                focusGrabTimer.restart()
            } else {
                root.wantsFocus = false
                focusGrabTimer.stop()
                closeTimer.restart()
            }
        }
    }

    Timer {
        id: closeTimer
        interval: Theme.animDuration + 20
        onTriggered: {
            if (!Popups.emojiOpen)
                root.windowVisible = false
        }
    }

    Item {
        id: sizer
        anchors.right:  parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: Theme.borderWidth
        anchors.bottomMargin: Theme.borderWidth
        clip: true

        width:  Popups.emojiOpen ? root.popupWidth  + root.fw : 0
        height: Popups.emojiOpen ? root.popupHeight + root.fh : 0

        Behavior on width  { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }
        Behavior on height { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }

        PopupShape {
            anchors.fill: parent
            attachedEdge: "bottom-right"
            color:        Theme.background
            radius:       Theme.cornerRadius
            flareWidth:   root.fw
            flareHeight:  root.fh
        }

        Item {
            id: content
            anchors {
                fill:         parent
                topMargin:    root.fh + 8
                leftMargin:   root.fw + 10
                bottomMargin: 8
            }

            opacity: Popups.emojiOpen ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Popups.emojiOpen ? Theme.animDuration * 0.5 : Theme.animDuration * 0.15
                }
            }

            EmojiPicker { anchors.fill: parent }
        }
    }
}
