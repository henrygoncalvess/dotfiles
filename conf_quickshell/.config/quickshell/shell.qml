//@ pragma UseQApplication
import QtQuick
import Quickshell

ShellRoot {
    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup() }
        function onReloadFailed(errorString) { Quickshell.inhibitReloadPopup() }
    }

    Main {}
    // TopBar {}       // Desabilitado — usando Waybar
    // Floating {}     // Desabilitado — os 3 tabModules (quickactions) foram removidos
}
