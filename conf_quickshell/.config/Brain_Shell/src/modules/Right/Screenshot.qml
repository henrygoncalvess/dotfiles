import QtQuick
import Quickshell
import "../../"

// Screenshot trigger. Left click selects a region (snapping to windows and
// monitors), right click takes the focused monitor whole; either way the shot
// opens in the annotation editor. Clicking again while the selection is up
// cancels it.
//
// Same shape as IconBtn, but written out because IconBtn only reports left
// clicks and this one needs the right button too.
Rectangle {
    id: root

    readonly property string script: "~/.config/hypr/scripts/screenshot-edit.sh"

    width: 24
    height: 24
    radius: 4
    color: hover.hovered ? Theme.active : "transparent"

    Text {
        anchors.centerIn: parent
        // nf-md-camera — never paste these glyphs literally, a Write eats them.
        // The codepoints the cheat sheet lists for the screenshot icons land on
        // unrelated glyphs in the Hasklug build installed here.
        text: String.fromCodePoint(0xF0100)
        color: hover.hovered ? Theme.background : Theme.text
        font.pixelSize: 14
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: function (mouse) {
            // Keep whatever popup is open out of the capture.
            Popups.closeAll()

            var mode = mouse.button === Qt.RightButton ? "fullscreen" : "smart"
            Quickshell.execDetached(["sh", "-c", root.script + " " + mode])
        }
    }
}
