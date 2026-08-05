import QtQuick
import Quickshell
import Quickshell.Io
import "../shapes"
import "../components"
import "../services"
import "../"
import Quickshell.Wayland

PanelWindow {
	id: root

	// Mantido só pra PopupLayer poder passar anchor sem quebrar
	property var anchorWindow

	readonly property int fw: Theme.cornerRadius
	readonly property int fh: Theme.cornerRadius

	readonly property var pageWidths: ({
		"output": 320,
		"input":  320,
		"mixer":  320
	})

	readonly property int popupHeight: 340

	readonly property int maxWidth: 320

	color:   "transparent"
	// Monitor desta cópia (PopupLayer é instanciado por tela). Sem `screen` as
	// cópias empilham no mesmo monitor e a de cima engole os cliques.
	property var popupScreen: null
	screen: popupScreen

	visible: slide.windowVisible && Popups.isActiveScreen(popupScreen)
	mask: Region { item: maskProxy }

	anchors.right: true
	// Not setting top or bottom centers it vertically on the right edge
	
	WlrLayershell.layer:         WlrLayer.Overlay
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
	exclusionMode: ExclusionMode.Ignore

	Item {
	    id:      maskProxy
	    x:       root.maxWidth - sizer.width
	    y:       (root.popupHeight - sizer.height) / 2
	    width:   sizer.width
	    height:  sizer.height
	}

	implicitWidth:  maxWidth
	implicitHeight: popupHeight
	
	PopupSlide {
		id: slide
		anchors.fill: parent
		edge:             "right"
		open:             Popups.audioOpen
		hoverEnabled:     true
		triggerHovered:   Popups.audioTriggerHovered
		onCloseRequested: Popups.audioOpen = false

		Connections {
			target: Popups
			function onAudioOpenChanged() {
				if (!Popups.audioOpen) audioResetTimer.restart()
                else audioControl.page = Popups.audioPage
			}

            function onAudioPageChanged() {
                audioControl.page = Popups.audioPage
            }
		}

		Timer {
			id: audioResetTimer
			interval: Theme.animDuration + 20
			onTriggered: audioControl.reset()
		}

		Item {
			id: sizer
			anchors.right:          parent.right
			anchors.verticalCenter: parent.verticalCenter
			clip: true

			width:  root.pageWidths[audioControl.page] || root.maxWidth
			height: root.popupHeight

			Behavior on width { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }

			PopupShape {
				id: bg
				anchors.fill: parent
				attachedEdge: "right"
				color:        Theme.background
				radius:       Theme.cornerRadius
				flareWidth:   0            // encostado na parede (sem gap do flare)
				flareHeight:  root.fh
			}

			AudioControl {
				id: audioControl
				anchors {
					fill:         parent
					topMargin:    root.fh + 6
					bottomMargin: root.fh + 6
					leftMargin:   10
					rightMargin:  root.fw - 4
				}
			}
		}
	}
}
