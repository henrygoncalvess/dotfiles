pragma Singleton
import QtQuick
import Quickshell

// ─────────────────────────────────────────────────────────────
// OldShell — drives the widgets of the 2nd instance (the old config in
// ~/.config/quickshell) through its "main".handleCommand IpcHandler.
//
// That 2nd instance only exists to provide the battery/calendar/music/
// network/wallpaper/clipboard widgets; its NotificationServer is disabled
// (Brain_Shell owns notifications).
//
// Usage: OldShell.toggle("battery", "")   // arg is optional (e.g. "wifi")
// ─────────────────────────────────────────────────────────────
QtObject {
    // When quickshell restarts itself after a crash, the recovered process keeps
    // __QUICKSHELL_CRASH_* in its environment, and every child it spawns
    // inherits them. A child that is itself quickshell then thinks it IS the
    // crash-recovery re-exec: it ignores the `ipc call` arguments entirely and
    // relaunches the parent's config instead. That spawned a whole extra
    // Brain_Shell — bar, borders and all — on every click that reached this
    // singleton, stacking one more bar down the screen each time. Scrubbing the
    // variables keeps the child an ordinary ipc client.
    readonly property string _scrubCrashEnv:
        "env -u __QUICKSHELL_CRASH_INFO_FD -u __QUICKSHELL_CRASH_DUMP_FD " +
        "-u __QUICKSHELL_CRASH_LOG_FD -u __QUICKSHELL_CRASH_DUMP_PID " +
        "-u __QUICKSHELL_CRASH_SIGNAL "

    // Resolve quickshell at runtime: native on arch/omarchy, nix on ubuntu
    // (Hyprland's exec does NOT inherit ~/.nix-profile/bin in PATH, hence the
    // absolute path fallback).
    readonly property string _cmd:
        "qs=$(command -v quickshell || echo ~/.nix-profile/bin/quickshell); " +
        "cfgDir=\"$HOME/.config/quickshell\"; " +
        _scrubCrashEnv + "\"$qs\" -p \"$cfgDir\" ipc call main handleCommand"

    function toggle(widget, arg) {
        Quickshell.execDetached(["sh", "-c",
            _cmd + " toggle " + widget + " '" + (arg || "") + "'"])
    }
}
