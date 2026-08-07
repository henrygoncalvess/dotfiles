import QtQuick
import QtQuick.Layouts
import "../services"
import "../"

Rectangle {
    id: root

    required property var streamNode
    property bool recording: false
    property bool systemCapture: false
    property var routeTargets: []
    property string routeCurrent: ""
    property string routeLabel: ""
    property bool routeOpen: false

    signal routePicked(var sink)

    readonly property bool audioReady: streamNode !== null && streamNode.ready && streamNode.audio !== null
    readonly property real rawVolume: audioReady ? Math.max(0, streamNode.audio.volume) : 0
    readonly property real volume: Math.min(1, rawVolume)
    readonly property bool muted: audioReady ? streamNode.audio.muted : false
    readonly property string appName: AudioService.streamName(streamNode)
    readonly property string mediaName: AudioService.streamMedia(streamNode)
    readonly property bool canRoute: !recording && routeTargets.length > 1

    implicitHeight: content.implicitHeight + 18
    radius: 9
    color: Qt.rgba(1, 1, 1, 0.035)
    border.color: Qt.rgba(1, 1, 1, 0.06)
    border.width: 1

    Behavior on implicitHeight {
        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }

    Column {
        id: content
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 9
        }
        spacing: 7

        RowLayout {
            width: parent.width
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 10
                color: root.muted ? Qt.rgba(0.95, 0.36, 0.40, 0.14) : Qt.rgba(1, 1, 1, 0.06)

                Text {
                    anchors.centerIn: parent
                    text: root.recording ? (root.systemCapture ? "󰕾" : "󰍬") : AudioService.streamIcon(root.streamNode)
                    color: root.muted ? "#f87171" : Qt.rgba(1, 1, 1, 0.65)
                    font.pixelSize: 15
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.audioReady && !AudioService.busy
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.streamNode.audio.muted = !root.streamNode.audio.muted
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: root.appName
                    color: Theme.text
                    font.pixelSize: 11
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    visible: root.recording || root.mediaName !== "" || root.routeCurrent !== ""
                    Layout.fillWidth: true
                    text: root.recording
                          ? (root.systemCapture ? "Capturing system audio" : "Using microphone")
                          : (root.mediaName !== "" ? root.mediaName : (root.routeLabel || root.routeCurrent))
                    color: Qt.rgba(1, 1, 1, 0.35)
                    font.pixelSize: 9
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                visible: root.canRoute
                Layout.preferredWidth: 27
                Layout.preferredHeight: 26
                radius: 8
                color: routeHover.hovered || root.routeOpen
                       ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.17)
                       : Qt.rgba(1, 1, 1, 0.055)

                Text {
                    anchors.centerIn: parent
                    text: "󰓃"
                    color: root.routeOpen ? Theme.active : Qt.rgba(1, 1, 1, 0.50)
                    font.pixelSize: 11
                }

                HoverHandler { id: routeHover; cursorShape: Qt.PointingHandCursor }
                MouseArea {
                    anchors.fill: parent
                    enabled: !AudioService.busy
                    onClicked: root.routeOpen = !root.routeOpen
                }
            }

            Text {
                Layout.preferredWidth: 36
                text: root.audioReady ? Math.round(root.rawVolume * 100) + "%" : "--%"
                color: root.muted ? Qt.rgba(1, 1, 1, 0.28)
                                  : (root.rawVolume > 1 ? "#f5a45d" : Theme.text)
                font.pixelSize: 10
                font.bold: true
                horizontalAlignment: Text.AlignRight
            }
        }

        Item {
            width: parent.width
            height: 8

            Rectangle {
                id: track
                anchors.fill: parent
                radius: 4
                color: Qt.rgba(1, 1, 1, 0.08)

                Rectangle {
                    height: parent.height
                    width: root.audioReady ? parent.width * root.volume : 0
                    radius: parent.radius
                    color: root.muted ? Qt.rgba(1, 1, 1, 0.18) : Theme.active
                    Behavior on width { NumberAnimation { duration: 70 } }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.audioReady && !AudioService.busy
                    cursorShape: enabled ? Qt.SizeHorCursor : Qt.ArrowCursor

                    function apply(mouseX) {
                        root.streamNode.audio.volume = Math.max(0, Math.min(1, mouseX / width))
                    }

                    onPressed: function(mouse) { apply(mouse.x) }
                    onPositionChanged: function(mouse) { if (pressed) apply(mouse.x) }
                }

                WheelHandler {
                    enabled: root.audioReady && !AudioService.busy
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: function(event) {
                        const step = event.angleDelta.y > 0 ? 0.05 : -0.05
                        root.streamNode.audio.volume = Math.max(0, Math.min(1, root.volume + step))
                    }
                }
            }
        }

        Column {
            visible: root.routeOpen && root.canRoute
            width: parent.width
            spacing: 3

            Text {
                text: "PLAY THROUGH"
                color: Qt.rgba(1, 1, 1, 0.34)
                font.pixelSize: 9
                font.bold: true
                font.letterSpacing: 0.8
                topPadding: 3
            }

            Repeater {
                model: root.routeTargets

                delegate: Rectangle {
                    id: sinkRow
                    required property var modelData
                    readonly property bool selected: modelData.name === root.routeCurrent

                    width: parent.width
                    height: 30
                    radius: 8
                    color: selected
                           ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.14)
                           : (sinkHover.hovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent")

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 9
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 36
                        text: sinkRow.modelData.label
                        color: sinkRow.selected ? Theme.active : Theme.text
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }

                    Text {
                        visible: sinkRow.selected
                        anchors.right: parent.right
                        anchors.rightMargin: 9
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰄬"
                        color: Theme.active
                        font.pixelSize: 11
                    }

                    HoverHandler { id: sinkHover; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !AudioService.busy
                        onClicked: {
                            root.routePicked(sinkRow.modelData)
                            root.routeOpen = false
                        }
                    }
                }
            }
        }
    }
}
