import Quickshell
import QtQuick
import "../components"
import "../"

// CavaBorderOverlay — transparent PanelWindow that hosts CavaBorder bars
// along one screen edge. Three instances (left, right, bottom) are created
// per monitor in shell.qml.

PanelWindow {
    id: root

    property string edge: "bottom"

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    mask: Region {} // Empty mask means no clicks are intercepted

    anchors {
        left:   (edge === "left"   || edge === "bottom")
        right:  (edge === "right"  || edge === "bottom")
        bottom: (edge === "left"   || edge === "right" || edge === "bottom")
        top:    (edge === "left"   || edge === "right")
    }

    // Must be >= maxDepth in CavaBorder.qml, otherwise bars get clipped.
    implicitWidth:  (edge === "left" || edge === "right") ? 84 : 0
    implicitHeight: (edge === "bottom") ? 84 : 0

    margins {
        // Don't overlap the topbar
        top: (edge !== "bottom") ? Theme.notchHeight : 0
    }

    CavaBorder {
        anchors.fill: parent
        edge: root.edge
    }
}
