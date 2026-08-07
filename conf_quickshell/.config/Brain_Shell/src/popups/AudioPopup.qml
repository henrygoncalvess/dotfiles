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
		"general":  450,
		"apps":     450,
		"advanced": 450,
		// Compatibilidade com os IPCs antigos.
		"output":   450,
		"input":    450,
		"mixer":    450,
		"config":   450
	})

	readonly property int popupHeight: 590

	readonly property int maxWidth: 450

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
		onWindowVisibleChanged: {
			AudioService.panelVisible = windowVisible
			if (windowVisible) {
				audioResetTimer.stop()
				AudioService.refresh()
			}
			else audioResetTimer.restart()
		}

		Connections {
			target: Popups
			function onAudioOpenChanged() {
				if (!Popups.audioOpen) audioResetTimer.restart()
				else {
					audioResetTimer.stop()
					AudioService.refresh()
				}
			}
		}

		Timer {
			id: audioResetTimer
			interval: Theme.animDuration + 20
			onTriggered: if (!slide.windowVisible) audioControl.reset()
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
					rightMargin:  Math.max(10, root.fw - 4)
				}
			}
		}
	}
}
