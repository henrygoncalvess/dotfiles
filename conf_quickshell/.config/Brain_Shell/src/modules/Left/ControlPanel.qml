import QtQuick
import Quickshell
import Quickshell.Io
import "../../components"
import "../../"

IconBtn {
    id: ctrl

    // Glyph da distro (Nerd Font) por codepoint, detectado do /etc/os-release.
    // Fallback = power-off (U+F011) se a distro não estiver no mapa.
    property string distroGlyph: String.fromCharCode(0xF011)
    text: distroGlyph

    Process {
        running: true
        command: ["sh", "-c", ". /etc/os-release 2>/dev/null; printf %s \"$ID\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var id = this.text.trim().toLowerCase()
                var map = {
                    "ubuntu":      0xF31B,
                    "arch":        0xF303,
                    "archlinux":   0xF303,
                    "debian":      0xF306,
                    "fedora":      0xF30A,
                    "manjaro":     0xF312,
                    "pop":         0xF32A,
                    "linuxmint":   0xF30E,
                    "endeavouros": 0xF322,
                    "nixos":       0xF313
                }
                if (map[id] !== undefined)
                    ctrl.distroGlyph = String.fromCharCode(map[id])
            }
        }
    }

    // Clique abre o widget "battery" da 2ª instância (config antiga).
    onClicked: {
        Popups.closeAll()
        OldShell.toggle("battery", "")
    }
}