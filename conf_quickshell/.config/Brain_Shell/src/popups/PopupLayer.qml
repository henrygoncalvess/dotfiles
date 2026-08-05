import QtQuick
import Quickshell
import "../"

// ============================================================
// PopupLayer — the only file that instantiates popup windows.
//
// shell.qml creates the anchor windows and passes them in.
// To add a new popup:
//   1. Create the .qml file in src/popups/
//   2. Add its anchor window as a property here (if new)
//   3. Instantiate it below under the right section
// ============================================================

Item {
    id: root

    // ── Anchor windows (set by shell.qml) ───────────────────
    required property var topBar       // TopBar PanelWindow
    required property var leftBorder   // left Border PanelWindow
    required property var rightBorder  // right Border PanelWindow
    required property var bottomBorder // bottom Border PanelWindow

    // ShellScreen of this layer. shell.qml creates one PopupLayer per monitor,
    // so every popup MUST receive it — without `screen` the copies from both
    // monitors land on the same screen, stacked (see the note in Popups.qml).
    required property var screenRef

    // ── Border-anchored popups ───────────────────────────────

    // Left border → center
    ArchMenu {
        popupScreen:  root.screenRef
        anchorWindow: root.leftBorder
    }

    // Bottom border → slides up
    // WallpaperPopup {}

    // Bottom-right corner → clipboard history
    ClipboardPopup {
        popupScreen: root.screenRef
    }

    // Bottom-right corner → emoji picker (SUPER + PERIOD)
    EmojiPopup {
        popupScreen: root.screenRef
    }

    // ── TopBar-anchored popups ───────────────────────────────

    // Right notch — audio
    AudioPopup {
        popupScreen:  root.screenRef
        anchorWindow: root.rightBorder
    }
    QuickControl {
        popupScreen:  root.screenRef
        anchorWindow: root.topBar
    }

    // Center notch — dashboard (expands below the center notch)
    Dashboard {
        popupScreen:  root.screenRef
        anchorWindow: root.topBar
    }

    // Right notch
    NotificationsPopup {
        popupScreen:  root.screenRef
        anchorWindow: root.topBar
    }

    NotificationToast {
        popupScreen:  root.screenRef
        anchorWindow: root.rightBorder
    }

    // Screen recorder strip options — appears below center notch on hover
    ScreenRecOptionsPopup {
        popupScreen:  root.screenRef
        anchorWindow: root.topBar
    }

    NetworkPopup {
        popupScreen: root.screenRef
    }
}
