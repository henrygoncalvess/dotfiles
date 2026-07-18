import QtQuick
import "../../components"
import "../../"

IconBtn {
    text: "󰍹"  // nf-md-monitor

    onClicked: {
        Popups.closeAll()
        OldShell.toggle("monitors", "")
    }
}
