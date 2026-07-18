pragma Singleton
import QtQuick
import Quickshell

// ─────────────────────────────────────────────────────────────
// OldShell — aciona os widgets da 2ª instância (config antiga em
// ~/.config/quickshell) via o IpcHandler "main".handleCommand.
//
// Essa 2ª instância roda só pra fornecer os widgets battery/calendar/
// music/network/wallpaper/clipboard; o NotificationServer dela está
// desligado (o Brain_Shell é quem detém as notificações).
//
// Uso: OldShell.toggle("battery", "")   // arg opcional (ex. "wifi")
// ─────────────────────────────────────────────────────────────
QtObject {
    // Caminho absoluto: exec do Hyprland NÃO herda o ~/.nix-profile/bin no PATH.
    readonly property string _cmd:
        "~/.nix-profile/bin/quickshell -p ~/.config/quickshell ipc call main handleCommand"

    function toggle(widget, arg) {
        Quickshell.execDetached(["sh", "-c",
            _cmd + " toggle " + widget + " '" + (arg || "") + "'"])
    }
}