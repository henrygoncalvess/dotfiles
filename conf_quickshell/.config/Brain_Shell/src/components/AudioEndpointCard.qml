import QtQuick
import QtQuick.Layouts
import "../services"
import "../"

Rectangle {
    id: root

    required property string heading
    required property bool input
    property var endpoint: null
    property var audioNode: null
    property var endpoints: []
    property bool selectorOpen: false
    property real signalLevel: 0

    signal devicePicked(var device)
    signal portPicked(var device, var port)

    readonly property var ports: endpoint?.ports ?? []
    readonly property var activePortData: ports.find(port => port.name === endpoint?.activePort) ?? null
    readonly property bool canChoose: endpoints.length > 1 || ports.length > 1
    readonly property bool audioReady: audioNode !== null && audioNode.ready && audioNode.audio !== null
    readonly property bool controlsSupported: audioReady && endpoint?.technical !== true
    readonly property real rawVolume: audioReady ? Math.max(0, audioNode.audio.volume) : 0
    readonly property real volume: Math.min(1, rawVolume)
    readonly property bool muted: audioReady ? audioNode.audio.muted : false
    readonly property real normalizedSignal: {
        // PipeWire reports the signal before the endpoint gain on this stack.
        // Include that gain so the label matches the level the user will hear
        // (or the level applications receive from the microphone).
        const peak = Math.max(0, Math.min(1, root.signalLevel * root.volume))
        if (!root.audioReady || root.muted || peak <= 0.001) return 0
        // Convert the useful -60 dB to 0 dB range into a visible 0..1 bar.
        return Math.max(0, Math.min(1, 1 + Math.log(peak) / Math.LN10 / 3))
    }
    readonly property string signalLabel: {
        if (root.muted) return "Muted"
        if (root.normalizedSignal < 0.04) return "Silent"
        if (root.normalizedSignal < 0.45) return "Low"
        if (root.normalizedSignal < 0.75) return "Medium"
        if (root.normalizedSignal < 0.90) return "Loud"
        return "Peak"
    }
    readonly property color signalColor: root.normalizedSignal >= 0.90 ? "#f87171"
                                         : (root.normalizedSignal >= 0.75 ? "#f5a45d" : Theme.active)
    readonly property int cardRadius: Math.max(9, Theme.cornerRadius)

    implicitHeight: body.implicitHeight + 24
    radius: cardRadius
    color: Qt.rgba(1, 1, 1, 0.045)
    border.color: selectorOpen
                  ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.40)
                  : Qt.rgba(1, 1, 1, 0.07)
    border.width: 1

    Behavior on implicitHeight {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    Column {
        id: body
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 12
        }
        spacing: 9

        Text {
            text: root.heading
            color: Qt.rgba(1, 1, 1, 0.42)
            font.pixelSize: 10
            font.bold: true
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.0
        }

        RowLayout {
            width: parent.width
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: 12
                color: root.muted
                       ? Qt.rgba(0.95, 0.36, 0.40, 0.16)
                       : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.14)

                Text {
                    anchors.centerIn: parent
                    text: AudioService.endpointIcon(root.endpoint?.icon ?? (root.input ? "microphone" : "output"), root.muted)
                    color: root.muted ? "#f87171" : Theme.active
                    font.pixelSize: 18
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.controlsSupported && !AudioService.busy
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.audioNode.audio.muted = !root.audioNode.audio.muted
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: root.endpoint?.label ?? (root.input ? "No microphone" : "No output")
                    color: Theme.text
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: {
                        if (!root.endpoint) return "Connect a device to continue"
                        if (!root.audioReady) return "Waiting for PipeWire…"
                        if (!root.controlsSupported) return "Pro Audio mode: use Pavucontrol for advanced controls"
                        if (root.muted) return root.input ? "Microphone muted" : "Output muted"
                        if (root.activePortData?.available === false)
                            return (root.activePortData?.label ?? "Connector") + " • forced"
                        if (root.ports.length > 0) return root.activePortData?.label ?? "Available"
                        return "Available"
                    }
                    color: root.muted ? "#f87171"
                                      : (root.activePortData?.available === false ? "#f5a45d" : Qt.rgba(1, 1, 1, 0.42))
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                visible: root.canChoose
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 9
                color: chooserHover.hovered || root.selectorOpen
                       ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
                       : Qt.rgba(1, 1, 1, 0.055)

                Text {
                    anchors.centerIn: parent
                    text: root.selectorOpen ? "󰅀" : "󰅂"
                    color: root.selectorOpen ? Theme.active : Qt.rgba(1, 1, 1, 0.55)
                    font.pixelSize: 13
                }

                HoverHandler { id: chooserHover; cursorShape: Qt.PointingHandCursor }
                MouseArea {
                    anchors.fill: parent
                    enabled: !AudioService.busy
                    onClicked: root.selectorOpen = !root.selectorOpen
                }
            }
        }

        RowLayout {
            width: parent.width
            spacing: 10

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 12

                Rectangle {
                    id: track
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 7
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, 0.09)

                    Rectangle {
                        width: root.audioReady ? parent.width * root.volume : 0
                        height: parent.height
                        radius: parent.radius
                        color: root.muted ? Qt.rgba(1, 1, 1, 0.20) : Theme.active
                        Behavior on width { NumberAnimation { duration: 70 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.controlsSupported && !AudioService.busy
                        cursorShape: enabled ? Qt.SizeHorCursor : Qt.ArrowCursor

                        function apply(mouseX) {
                            const value = Math.max(0, Math.min(1, mouseX / width))
                            root.audioNode.audio.volume = value
                        }

                        onPressed: function(mouse) { apply(mouse.x) }
                        onPositionChanged: function(mouse) { if (pressed) apply(mouse.x) }
                    }

                    WheelHandler {
                        enabled: root.controlsSupported && !AudioService.busy
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: function(event) {
                            const step = event.angleDelta.y > 0 ? 0.05 : -0.05
                            root.audioNode.audio.volume = Math.max(0, Math.min(1, root.volume + step))
                        }
                    }
                }
            }

            Text {
                Layout.preferredWidth: 38
                text: root.audioReady ? Math.round(root.rawVolume * 100) + "%" : "--%"
                color: root.muted ? Qt.rgba(1, 1, 1, 0.30)
                                  : (root.rawVolume > 1 ? "#f5a45d" : Theme.text)
                font.pixelSize: 11
                font.bold: true
                horizontalAlignment: Text.AlignRight
            }
        }

        RowLayout {
            width: parent.width
            spacing: 8

            Text {
                Layout.preferredWidth: 29
                text: "LIVE"
                color: root.normalizedSignal > 0 ? root.signalColor : Qt.rgba(1, 1, 1, 0.30)
                font.pixelSize: 8
                font.bold: true
                font.letterSpacing: 0.7
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 10

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 5
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, 0.075)

                    Rectangle {
                        width: parent.width * root.normalizedSignal
                        height: parent.height
                        radius: parent.radius
                        color: root.signalColor
                        Behavior on width { NumberAnimation { duration: 85; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 90 } }
                    }
                }
            }

            Text {
                Layout.preferredWidth: 45
                text: root.signalLabel
                color: root.normalizedSignal > 0 ? root.signalColor : Qt.rgba(1, 1, 1, 0.34)
                font.pixelSize: 9
                font.bold: root.normalizedSignal >= 0.75
                horizontalAlignment: Text.AlignRight
            }
        }

        Column {
            visible: root.selectorOpen && root.canChoose
            width: parent.width
            spacing: 4

            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(1, 1, 1, 0.07)
            }

            Text {
                visible: root.endpoints.length > 1
                text: root.input ? "MICROPHONES" : "DEVICES"
                color: Qt.rgba(1, 1, 1, 0.34)
                font.pixelSize: 9
                font.bold: true
                font.letterSpacing: 0.8
                topPadding: 3
            }

            Repeater {
                model: root.endpoints.length > 1 ? root.endpoints : []

                delegate: Rectangle {
                    id: deviceRow
                    required property var modelData
                    readonly property bool selected: modelData.name === root.endpoint?.name

                    width: parent.width
                    height: 34
                    radius: 8
                    color: selected
                           ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.14)
                           : (deviceHover.hovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent")

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 38
                        text: deviceRow.modelData.label
                        color: deviceRow.selected ? Theme.active : Theme.text
                        font.pixelSize: 11
                        font.bold: deviceRow.selected
                        elide: Text.ElideRight
                    }

                    Text {
                        visible: deviceRow.selected
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰄬"
                        color: Theme.active
                        font.pixelSize: 12
                    }

                    HoverHandler { id: deviceHover; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !AudioService.busy
                        onClicked: {
                            root.devicePicked(deviceRow.modelData)
                            root.selectorOpen = false
                        }
                    }
                }
            }

            Text {
                visible: root.ports.length > 1
                text: "CONNECTOR"
                color: Qt.rgba(1, 1, 1, 0.34)
                font.pixelSize: 9
                font.bold: true
                font.letterSpacing: 0.8
                topPadding: 4
            }

            Repeater {
                model: root.ports.length > 1 ? root.ports : []

                delegate: Rectangle {
                    id: portRow
                    required property var modelData
                    readonly property bool selected: modelData.name === root.endpoint?.activePort

                    width: parent.width
                    height: modelData.available === false ? 42 : 32
                    radius: 8
                    color: selected
                           ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.14)
                           : (portHover.hovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent")

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 76
                        spacing: 1

                        Text {
                            width: parent.width
                            text: portRow.modelData.label
                            color: portRow.selected ? Theme.active : Theme.text
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }

                        Text {
                            visible: portRow.modelData.available === false
                            width: parent.width
                            text: "Not detected • click to force"
                            color: "#f5a45d"
                            font.pixelSize: 8
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        visible: portRow.selected || portRow.modelData.available === false
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: portRow.selected ? "󰄬" : "Force"
                        color: portRow.selected ? Theme.active : "#f5a45d"
                        font.pixelSize: portRow.selected ? 12 : 8
                        font.bold: !portRow.selected
                    }

                    HoverHandler { id: portHover; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !AudioService.busy
                        onClicked: {
                            root.portPicked(root.endpoint, portRow.modelData)
                            root.selectorOpen = false
                        }
                    }
                }
            }
        }
    }
}
