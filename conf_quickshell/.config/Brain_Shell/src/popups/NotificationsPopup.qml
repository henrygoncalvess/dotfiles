import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../components"
import "../shapes/"
import "../services/"
import "../"

// PanelWindow (layer surface, namespace "quickshell") em vez de PopupWindow:
// no Hyprland 0.55 o blur (layerrule namespace quickshell) só pega superfícies
// de layer — xdg-popups NÃO recebem blur. Modelado no NetworkPopup, que já é
// um PanelWindow ancorado top-right e cresce pra esquerda/baixo.
PanelWindow {
    id: root

    // Mantido só pra PopupLayer poder passar anchorWindow: topBar sem quebrar.
    property var anchorWindow

    readonly property int popupWidth:   Theme.notificationsWidth
    readonly property int maxHeight:    700
    readonly property int fw:           Theme.notchRadius
    readonly property int fh:           Theme.notchRadius
    readonly property int animDuration: Theme.animDuration

    anchors.right: true
    anchors.top:   true

    implicitWidth:  popupWidth + fw
    implicitHeight: maxHeight

    exclusionMode: ExclusionMode.Ignore
    color:         "transparent"

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Máscara limita a região de input ao sizer visível.
    mask: Region { item: maskProxy }
    Item {
        id:     maskProxy
        x:      root.implicitWidth - sizer.width
        y:      0
        width:  sizer.width
        height: sizer.height
    }

    // ── Visibility gate ───────────────────────────────────────
    property bool windowVisible: false
    visible: windowVisible

    Connections {
        target: Popups
        function onNotificationsOpenChanged() {
            if (Popups.notificationsOpen) {
                closeTimer.stop()
                root.windowVisible = true
            } else {
                closeTimer.restart()
            }
        }
    }

    Timer {
        id:       closeTimer
        interval: root.animDuration + 20
        onTriggered: { if (!Popups.notificationsOpen) root.windowVisible = false }
    }

    // ── Sizer ─────────────────────────────────────────────────
    // Ancorado top-right; cresce pra esquerda + baixo a partir do notch direito.
    Item {
        id:            sizer
        anchors.right: parent.right
        y:             0
        clip:          true

        width: Popups.notificationsOpen
               ? Theme.notificationsWidth + root.fw
               : Theme.rNotchMinWidth + root.fw

        height: Popups.notificationsOpen
                ? notifList.height + Theme.popupPadding * 2 + root.fh
                : root.fh

        Behavior on width  { NumberAnimation { duration: root.animDuration; easing.type: Easing.InOutCubic } }
        Behavior on height { NumberAnimation { duration: root.animDuration; easing.type: Easing.InOutCubic } }

        // ── Background ─────────────────────────────────────────
        PopupShape {
            anchors.fill: parent
            attachedEdge: "top"
            color:        Theme.background
            radius:       Theme.cornerRadius
            flareWidth:   root.fw
            flareHeight:  root.fh
        }

        // ── Content ────────────────────────────────────────────
        Item {
            anchors {
                fill:         parent
                topMargin:    root.fh + 4
                leftMargin:   root.fw + 4
                rightMargin:  4
                bottomMargin: 4
            }

            opacity: Popups.notificationsOpen ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Popups.notificationsOpen
                              ? root.animDuration * 0.5
                              : root.animDuration * 0.15
                }
            }

            NotificationList {
                id:    notifList
                width: parent.width
            }
        }
    }
}