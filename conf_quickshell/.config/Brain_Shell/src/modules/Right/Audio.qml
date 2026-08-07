import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../../components"
import "../../services"
import "../../"

Item {
    id: root

    property bool showPercentage: false

    implicitWidth:  row.implicitWidth + 6
    implicitHeight: row.implicitHeight

    // EasyEffects exposes a virtual sink, but it is not a speaker. Keep the bar
    // tied to the actual device even if an old configuration made that virtual
    // node the default.
    readonly property var sink: {
        const current = Pipewire.defaultAudioSink
        if (current && current.name !== "easyeffects_sink" &&
                current.properties?.["node.virtual"] !== "true")
            return current

        const nodes = Pipewire.nodes.values
        for (let i = 0; i < nodes.length; i++) {
            const node = nodes[i]
            if (!node.isStream && node.isSink && node.audio !== null &&
                    node.name !== "easyeffects_sink" &&
                    node.properties?.["node.virtual"] !== "true")
                return node
        }
        return current
    }

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    readonly property string icon: {
        if (!sink?.ready)            return "󰕾"
        if (sink.audio.muted)        return "󰝟"
        if (sink.audio.volume > 0.6) return "󰕾"
        if (sink.audio.volume > 0.2) return "󰖀"
        return "󰕿"
    }

    readonly property int pct: sink?.ready ? Math.round(sink.audio.volume * 100) : 0

    HoverHandler {
        id: hov
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 3

        Text {
            id: iconText
            text:           root.icon
            color:          hov.hovered ? Theme.active : Theme.text
            font.pixelSize: 18
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Item {
            id: pctWrapper
            property bool show: root.showPercentage   // não expande no hover (sem mover a barra)
            implicitWidth: show ? pctText.implicitWidth + 2 : 0
            implicitHeight: pctText.implicitHeight
            clip: true
            anchors.verticalCenter: parent.verticalCenter
            Behavior on implicitWidth { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }
        
            Text {
                id: pctText
                text:           root.pct + "%"
                color:          hov.hovered ? Theme.active : Theme.text
                font.pixelSize: 12
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }
    }

    MouseArea {
        anchors.fill:        parent
        acceptedButtons:     Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                Quickshell.execDetached([AudioService.backend, "key-volume", "mute-toggle"])
            } else if (mouse.button === Qt.MiddleButton) {
                // O player visual antigo continua disponível, mas não disputa
                // mais o clique principal com os controles de áudio.
                Popups.closeAll()
                OldShell.toggle("music", "")
            } else {
                const next = !Popups.audioOpen
                Popups.closeAll()
                Popups.audioPage = "general"
                Popups.audioOpen = next
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
            Quickshell.execDetached([
                AudioService.backend,
                "key-volume",
                event.angleDelta.y > 0 ? "raise" : "lower"
            ])
        }
    }
}
