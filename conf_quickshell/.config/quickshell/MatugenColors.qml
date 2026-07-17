import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // Explicitly typed as 'color' for strict QML binding
    property color base: "#CC0D0F16"
    property color mantle: "#CC090A0F"
    property color crust: "#CC050508"
    property color text: "#d0cfcc"
    property color subtext0: "#a3a6b5"
    property color subtext1: "#b5b8c9"
    property color surface0: "#222533"
    property color surface1: "#32364a"
    property color surface2: "#454a66"
    property color overlay0: "#5a6082"
    property color overlay1: "#70769e"
    property color overlay2: "#878ebb"
    property color blue: "#298DFF"
    property color sapphire: "#2a7bde"
    property color peach: "#298DFF" // replaced warm color
    property color green: "#50fa7b"
    property color red: "#ff5555"
    property color mauve: "#298DFF" // replaced purple accent
    property color pink: "#298DFF" // replaced purple accent
    property color yellow: "#50fa7b" // replaced warm color
    property color maroon: "#ff5555" // replaced warm color
    property color teal: "#66daff"

    property string rawJson: ""

    Process {
        id: themeReader
        command: ["cat", "/tmp/qs_colors.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt !== "" && txt !== root.rawJson) {
                    root.rawJson = txt;
                    try {
                        let c = JSON.parse(txt);
                        if (c.base) root.base = c.base;
                        if (c.mantle) root.mantle = c.mantle;
                        if (c.crust) root.crust = c.crust;
                        if (c.text) root.text = c.text;
                        if (c.subtext0) root.subtext0 = c.subtext0;
                        if (c.subtext1) root.subtext1 = c.subtext1;
                        if (c.surface0) root.surface0 = c.surface0;
                        if (c.surface1) root.surface1 = c.surface1;
                        if (c.surface2) root.surface2 = c.surface2;
                        if (c.overlay0) root.overlay0 = c.overlay0;
                        if (c.overlay1) root.overlay1 = c.overlay1;
                        if (c.overlay2) root.overlay2 = c.overlay2;
                        if (c.blue) root.blue = c.blue;
                        if (c.sapphire) root.sapphire = c.sapphire;
                        if (c.peach) root.peach = c.peach;
                        if (c.green) root.green = c.green;
                        if (c.red) root.red = c.red;
                        if (c.mauve) root.mauve = c.mauve;
                        if (c.pink) root.pink = c.pink;
                        if (c.yellow) root.yellow = c.yellow;
                        if (c.maroon) root.maroon = c.maroon;
                        if (c.teal) root.teal = c.teal;
                    } catch(e) {}
                }
            }
        }
    }

    Timer {
        interval: 1000 
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: themeReader.running = true
    }
}
