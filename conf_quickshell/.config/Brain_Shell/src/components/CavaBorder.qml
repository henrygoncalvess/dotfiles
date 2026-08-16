import QtQuick
import "../"

// CavaBorder — renders CAVA audio bars along one screen edge.
//
// Props:
//   edge: "left" | "right" | "bottom"
//
// Left/Right: vertical Column of horizontal bars growing inward, spanning full height.
// Bottom:     horizontal Row of vertical bars growing upward, spanning full width.
//
// Visibility is tied to ShellState.cavaBorders && CavaService.isPlaying.
//
// ── Tuning knobs ─────────────────────────────────────────────────────────────
//   maxDepth  — how far bars extend inward at full amplitude (px)
//   barGap    — spacing between bars (px)
//   barThick  — computed automatically to fill the full edge, or set manually
//   alphaMin / alphaMax — opacity range based on amplitude

Item {
    id: root

    property string edge: "bottom"

    readonly property int barCount: CavaService.barCount   // 32
    readonly property var bars:     CavaService.bars

    // ── Tuning — edit these to taste ─────────────────────────────────────────
    property real maxDepth:  68    // max bar extension in px at full amplitude
    property real barGapSides:    15  // gap between bars on left/right edges
    property real barGapBottom:   33  // gap between bars on bottom edge
    property real barThickSides:  18  // thickness of bars on left/right edges
    property real barThickBottom: 24  // thickness of bars on the bottom edge
    property real alphaMin:  0.1  // opacity when amplitude = 0
    property real alphaMax:  1.0  // opacity when amplitude = 1

    readonly property real barThick: (edge === "bottom") ? barThickBottom : barThickSides
    readonly property real currentGap: (edge === "bottom") ? barGapBottom : barGapSides

    // ── Visibility ───────────────────────────────────────────────────────────
    opacity: (ShellState.cavaBorders && CavaService.isPlaying) ? 1 : 0
    visible: opacity > 0
    Behavior on opacity {
        NumberAnimation { duration: 300; easing.type: Easing.InOutCubic }
    }

    // ── Bottom edge — vertical bars growing upward, centered ─────────────────
    Row {
        visible: root.edge === "bottom"
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: root.currentGap

        Repeater {
            model: root.visible ? root.bars : null
            delegate: Item {
                required property int modelData
                width:  root.barThick
                height: root.maxDepth

                readonly property real amp: modelData / 100.0

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width:  root.barThick
                    height: Math.max(2, amp * root.maxDepth)
                    radius: width / 2
                    color:  Qt.rgba(
                        Theme.active.r, Theme.active.g, Theme.active.b,
                        root.alphaMin + amp * (root.alphaMax - root.alphaMin))
                    Behavior on height {
                        NumberAnimation { duration: 50; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }

    // ── Left edge — horizontal bars growing rightward, centered ──────────────
    Column {
        visible: root.edge === "left"
        anchors.left:   parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.currentGap

        Repeater {
            model: root.visible ? root.bars : null
            delegate: Item {
                required property int modelData
                width:  root.maxDepth
                height: root.barThick

                readonly property real amp: modelData / 100.0

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width:  Math.max(2, amp * root.maxDepth)
                    height: root.barThick
                    radius: height / 2
                    color:  Qt.rgba(
                        Theme.active.r, Theme.active.g, Theme.active.b,
                        root.alphaMin + amp * (root.alphaMax - root.alphaMin))
                    Behavior on width {
                        NumberAnimation { duration: 50; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }

    // ── Right edge — horizontal bars growing leftward, centered ──────────────
    Column {
        visible: root.edge === "right"
        anchors.right:  parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.currentGap

        Repeater {
            model: root.visible ? root.bars : null
            delegate: Item {
                required property int modelData
                width:  root.maxDepth
                height: root.barThick

                readonly property real amp: modelData / 100.0

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width:  Math.max(2, amp * root.maxDepth)
                    height: root.barThick
                    radius: height / 2
                    color:  Qt.rgba(
                        Theme.active.r, Theme.active.g, Theme.active.b,
                        root.alphaMin + amp * (root.alphaMax - root.alphaMin))
                    Behavior on width {
                        NumberAnimation { duration: 50; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }
}
