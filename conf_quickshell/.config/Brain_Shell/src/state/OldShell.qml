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
    // Resolve o quickshell em runtime: nativo no arch/omarchy, nix no ubuntu
    // (o exec do Hyprland NÃO herda o ~/.nix-profile/bin no PATH, por isso o
    // fallback usa o caminho absoluto).
    readonly property string _cmd:
        "qs=$(command -v quickshell || echo ~/.nix-profile/bin/quickshell); " +
        "$qs -p ~/.config/quickshell ipc call main handleCommand"

    function toggle(widget, arg) {
        Quickshell.execDetached(["sh", "-c",
            _cmd + " toggle " + widget + " '" + (arg || "") + "'"])
    }
}