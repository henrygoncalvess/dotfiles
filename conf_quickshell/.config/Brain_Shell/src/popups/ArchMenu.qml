import QtQuick
import Quickshell
import Quickshell.Io
import "../shapes"
import "../services"
import "../components"
import "../"

import Quickshell.Wayland

PanelWindow {
	id: root

	// Mantido só pra PopupLayer poder passar anchorWindow sem quebrar
	property var anchorWindow

	readonly property int fw: Theme.cornerRadius
	readonly property int fh: Theme.cornerRadius

	readonly property var pageHeights: ({
		"power":       270,
		"performance": 190,
		"stats":       250
	})
	readonly property var pageWidths: ({
		"power":       220,
		"performance": 260,
		"stats":       390
	})

	readonly property int contentWidth:  pageWidths[page]  ?? 220
	readonly property int contentHeight: pageHeights[page] ?? 220

	property string page: "power"

	color:   "transparent"
	// Monitor desta cópia (PopupLayer é instanciado por tela). Sem `screen` as
	// cópias empilham no mesmo monitor e a de cima engole os cliques.
	property var popupScreen: null
	screen: popupScreen

	visible: slide.windowVisible && Popups.isActiveScreen(popupScreen)
	mask: Region { item: maskProxy }

	implicitWidth:  (pageWidths["stats"]  ?? 220) + fw
	implicitHeight: (pageHeights["stats"] ?? 220) + fh * 2

	anchors.left: true
	// Not setting top or bottom centers it vertically on the left edge

	WlrLayershell.layer:         WlrLayer.Overlay
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
	exclusionMode: ExclusionMode.Ignore
	Item {
		id:      maskProxy
		x:       0
		y:       (root.implicitHeight - sizer.height) / 2-root.fh
		width:   sizer.width
		height:  sizer.height
	}
	
	PopupSlide {
		id: slide
		anchors.fill: parent
		edge:             "left"
		hoverEnabled:     false
		triggerHovered:   Popups.archMenuTriggerHovered
		open:             Popups.archMenuOpen
		onCloseRequested: Popups.archMenuOpen = false

		Item {
			id: sizer
			anchors.left:           parent.left
			anchors.verticalCenter: parent.verticalCenter
			clip: true

			width:  root.contentWidth  + root.fw
			height: root.contentHeight + root.fh * 2

			Behavior on width  { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }
			Behavior on height { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }

			PopupShape {
				id: bg
				anchors.fill: parent
				attachedEdge: "left"
				color:        Theme.background
				radius:       Theme.cornerRadius
				flareWidth:   0            // encostado na parede (sem gap do flare)
				flareHeight:  root.fh
			}

			Item {
				anchors {
					fill:         parent
					leftMargin:   root.fw - 4
					rightMargin:  8
					topMargin:    root.fh + 6
					bottomMargin: root.fh + 6
				}
					//── Page content ──────────────────────────────────────────
					Item {
						width:  parent.width
						height: parent.height
						clip:   true

						PopupPage {
							anchors.fill: parent
							visible: root.page === "power"

							PowerMenu {
								width: parent.width
							}
						}
				}
			}
		}
	}
}