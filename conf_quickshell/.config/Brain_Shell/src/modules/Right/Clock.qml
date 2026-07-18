import QtQuick
import "../../"

Text {
    id: clock
    text: Qt.formatDateTime(new Date(), "hh:mm:ss")
    color: clockHov.hovered ? Theme.active : Theme.text
    Behavior on color { ColorAnimation { duration: 120 } }
    font.bold: true
    anchors.verticalCenter: parent.verticalCenter
    font.pixelSize: 16

    property int formatMode: 0

    state: "timeSeconds"
    states: [
        State {
            name: "time"
            PropertyChanges { target: clock; formatMode: 0 }
        },
        State {
            name: "timeSeconds"
            PropertyChanges { target: clock; formatMode: 1 }
        },
        State {
            name: "date"
            PropertyChanges { target: clock; formatMode: 2 }
        }
    ]

    HoverHandler { id: clockHov }
    MouseArea {
        anchors.fill: parent
        acceptedButtons:     Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                // clique direito: cicla o formato (hora → segundos → data)
                if (clock.state === "time") clock.state = "timeSeconds"
                else if (clock.state === "timeSeconds") clock.state = "date"
                else clock.state = "time"
                updateText()
            } else {
                // clique esquerdo: abre o widget "calendar" (config antiga)
                Popups.closeAll()
                OldShell.toggle("calendar", "")
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: updateText()
    }

    function updateText() {
        let now = new Date()
        switch(formatMode) {
            case 0:
                text = Qt.formatDateTime(now, "hh:mm")
                break
            case 1:
                text = Qt.formatDateTime(now, "hh:mm:ss")
                break
            case 2:
                text = Qt.formatDateTime(now, "dd-MM-yyyy")
                break
        }
    }

    Component.onCompleted: updateText()
}
