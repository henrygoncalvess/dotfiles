pragma Singleton
import QtQuick
import Quickshell.Hyprland
import "../"

QtObject {
    id: popups

    // ── Which monitor popups show up on ──────────────────────────────────────
    // shell.qml instantiates PopupLayer once per screen (Variants over
    // Quickshell.screens), so every popup is born N times, N = monitor count.
    // Since none of them set `screen`, all N copies landed on the same monitor,
    // stacked: the top one held Exclusive keyboardFocus and swallowed the
    // clicks while the one below only showed up behind it. That was the "two
    // menus" / "two clipboards" bug.
    //
    // Each copy is now pinned to its own monitor (popupScreen) and only the one
    // under the cursor stays visible. The name is locked in when the first
    // popup opens so it cannot jump screens if focus changes afterwards.
    property string activeScreenName: ""

    onAnyOpenChanged: {
        if (anyOpen)
            activeScreenName = Hyprland.focusedMonitor?.name ?? ""
    }
    // ── Per-popup open state ───────────────────────────────────────────────────
    property bool audioOpen:         false
    property bool networkOpen:       false
    property bool batteryOpen:       false
    property bool notificationsOpen: false
    property bool archMenuOpen:      false
    property bool dashboardOpen:     false
    property bool wallpaperOpen:     false
    property bool notificationToastOpen:    false
    property bool quickOpen: false
    property bool clipboardOpen:     false
    property bool emojiOpen:         false

    // ── Dashboard — per-page state ───────────────────────────────────────────
    property int    dashboardPageWidth: 900
    property string dashboardPage:      "home"
    
    // ── Audio popup — per-page state ─────────────────────────────────────────
    property string audioPage: "output"

    // ── Network popup — per-page content (string key) ─────────────────────────
    property string networkPage: "wifi"

    // ── Per-popup trigger hover state ─────────────────────────────────────────
    property bool archMenuTriggerHovered: false
    property bool audioTriggerHovered:         false
    property bool networkTriggerHovered:       false
    property bool batteryTriggerHovered:       false
    property bool notificationsTriggerHovered: false
    property bool wallpaperTriggerHovered:     false
    property bool quickTriggerHovered: false

    // ── Universal popup behavior settings ─────────────────────────────────────
    property int  slideDuration:   Theme.animDuration
    property int  hoverCloseDelay: Theme.animDuration + 200   // delay after hover leaves before closing

    // ── Confirm dialog ────────────────────────────────────────────────────────
    property bool   confirmOpen:    false
    property string confirmTitle:   ""
    property string confirmMessage: ""
    property string confirmLabel:   "Confirm"
    property string confirmAction:  ""
    property string confirmGfxMode: ""
    property bool   confirmRunning: false

    function showConfirm(title, message, label, action, gfxMode) {
        confirmTitle   = title
        confirmMessage = message
        confirmLabel   = label
        confirmAction  = action
        confirmGfxMode = gfxMode ?? ""
        confirmOpen    = true
    }

    function cancelConfirm() {
        confirmOpen    = false
        confirmAction  = ""
        confirmGfxMode = ""
    }

    // ── Global state ──────────────────────────────────────────────────────────
    readonly property bool anyOpen: audioOpen || networkOpen || batteryOpen
                                    || notificationsOpen || archMenuOpen
                                    || dashboardOpen || wallpaperOpen || quickOpen
                                    || clipboardOpen || emojiOpen

    // A popup only materializes on the active screen. `screenRef` is the layer's
    // ShellScreen; while nothing is open (activeScreenName empty) any screen
    // will do, otherwise the popup stays hidden outside the chosen monitor.
    function isActiveScreen(screenRef) {
        if (activeScreenName === "" || !screenRef)
            return true
        return activeScreenName === screenRef.name
    }

    // For windows that never go through an "open" state (notification toast,
    // recorder strip): they follow whichever monitor has focus right now.
    function isFocusedScreen(screenRef) {
        const focused = Hyprland.focusedMonitor?.name ?? ""
        if (focused === "" || !screenRef)
            return true
        return focused === screenRef.name
    }

    function closeAll() {
        audioOpen         = false
        networkOpen       = false
        batteryOpen       = false
        notificationsOpen = false
        archMenuOpen      = false
        dashboardOpen     = false
        wallpaperOpen     = false
        quickOpen         = false
        clipboardOpen     = false
        emojiOpen         = false
    }
}
