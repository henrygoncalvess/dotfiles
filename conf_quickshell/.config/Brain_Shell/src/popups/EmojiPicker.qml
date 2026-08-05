import QtQuick
import QtQuick.Controls
import "../components"
import "../"

// Emoji picker body: search field, category strip and grid.
// Picking copies the emoji and closes the popup; with wtype installed it is
// also typed into whatever window had focus.

Item {
    id: root

    // -1 is the recents page, 0..n-1 index EmojiService.categories.
    property int    category:    -1
    property string searchQuery: ""

    // Name shown in the footer: hover wins over the keyboard highlight.
    property string hoverName: ""

    readonly property var results: EmojiService.results(root.searchQuery, root.category)
    readonly property bool searching: root.searchQuery.trim() !== ""

    onResultsChanged: grid.currentIndex = 0

    // Icon per category. Written as codepoints because literal glyphs do not
    // survive every editor round-trip. A category missing from the map falls
    // back to its own first emoji, so a new Unicode group still gets an icon.
    readonly property var categoryIcons: ({
        "Smileys & Emotion": 0x1F600,   // grinning face
        "People & Body":     0x1F44B,   // waving hand
        "Animals & Nature":  0x1F436,   // dog face
        "Food & Drink":      0x1F354,   // hamburger
        "Travel & Places":   0x1F30D,   // globe
        "Activities":        0x26BD,    // soccer ball
        "Objects":           0x1F4A1,   // light bulb
        "Symbols":           0x1F523,   // input symbols
        "Flags":             0x1F3C1    // chequered flag
    })

    // Category strip: a clock for the recents, then one tab per category.
    readonly property var tabs: {
        var list = [{ key: "recent", icon: String.fromCodePoint(0x1F553) }]

        for (var i = 0; i < EmojiService.categories.length; i++) {
            var code = root.categoryIcons[EmojiService.categories[i]]
            var icon = code !== undefined ? String.fromCodePoint(code) : ""

            if (icon === "") {
                var first = EmojiService.entries.find(function (e) { return e.g === i })
                icon = first ? first.c : "?"
            }

            list.push({ key: String(i), icon: icon })
        }

        return list
    }

    // Reset to a clean sheet every time the popup opens.
    Connections {
        target: Popups
        function onEmojiOpenChanged() {
            if (!Popups.emojiOpen) return

            root.searchQuery = ""
            root.hoverName   = ""
            root.category    = EmojiService.recents.length > 0 ? -1 : 0
            searchInput.text = ""
            focusTimer.restart()
        }
    }

    Timer {
        id: focusTimer
        interval: 100
        onTriggered: searchInput.forceActiveFocus()
    }

    Column {
        anchors.fill: parent
        spacing: 0

        // ── Header ─────────────────────────────────────────────────────────────
        Item {
            width:  parent.width
            height: 44

            Text {
                anchors.centerIn: parent
                text:           "Emoji"
                font.pixelSize: 14
                font.weight:    Font.DemiBold
                color:          Theme.text
            }

            // Clear recents — only meaningful on the recents page
            Rectangle {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 4 }
                width:  clearRow.implicitWidth + 14
                height: 26; radius: 8
                visible: root.category === -1 && !root.searching && EmojiService.recents.length > 0
                color: clearH.hovered
                    ? Qt.rgba(248/255, 113/255, 113/255, 0.18)
                    : Qt.rgba(1, 1, 1, 0.04)
                border.color: Qt.rgba(248/255, 113/255, 113/255, clearH.hovered ? 0.38 : 0.12)
                border.width: 1
                Behavior on color        { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Row {
                    id: clearRow
                    anchors.centerIn: parent
                    spacing: 5
                    Text {
                        text: "󰩺"; font.pixelSize: 12
                        color: Qt.rgba(248/255, 113/255, 113/255, 0.80)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Clear"; font.pixelSize: 10
                        color: Qt.rgba(248/255, 113/255, 113/255, 0.80)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                HoverHandler { id: clearH; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: EmojiService.clearRecents() }
            }
        }

        // Divider
        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.07) }

        // ── Search bar ─────────────────────────────────────────────────────────
        Item {
            width:  parent.width
            height: 36

            Rectangle {
                anchors {
                    fill: parent
                    leftMargin: 8; rightMargin: 8
                    topMargin: 5; bottomMargin: 3
                }
                radius: 8
                color: searchInput.activeFocus
                    ? Qt.rgba(1, 1, 1, 0.08)
                    : Qt.rgba(1, 1, 1, 0.04)
                border.color: searchInput.activeFocus
                    ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35)
                    : Qt.rgba(1, 1, 1, 0.08)
                border.width: 1
                Behavior on color        { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Row {
                    anchors {
                        fill: parent
                        leftMargin: 8; rightMargin: 6
                    }
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        // Nerd Font glyphs are built from their codepoint: pasting
                        // them literally does not survive every editor round-trip.
                        text: String.fromCharCode(0xF002)   // magnifier
                        font.pixelSize: 12
                        color: Qt.rgba(1, 1, 1, 0.28)
                    }

                    TextField {
                        id: searchInput
                        width: parent.width - 24
                        anchors.verticalCenter: parent.verticalCenter
                        placeholderText: "Search emoji…"
                        placeholderTextColor: Qt.rgba(1, 1, 1, 0.20)
                        font.pixelSize: 12
                        color: Theme.text
                        background: Item {}
                        padding: 0
                        topPadding: 0; bottomPadding: 0
                        leftPadding: 0; rightPadding: 0

                        onTextChanged: root.searchQuery = text

                        Keys.onEscapePressed: {
                            if (text !== "") {
                                text = ""
                            } else {
                                Popups.emojiOpen = false
                            }
                        }

                        // The grid never takes focus, so drive it from here.
                        // Left/right stay with the cursor while there is text.
                        Keys.onPressed: function (event) {
                            switch (event.key) {
                            case Qt.Key_Down:
                                grid.moveCurrentIndexDown();  event.accepted = true; break
                            case Qt.Key_Up:
                                grid.moveCurrentIndexUp();    event.accepted = true; break
                            case Qt.Key_Right:
                                if (text === "") { grid.moveCurrentIndexRight(); event.accepted = true }
                                break
                            case Qt.Key_Left:
                                if (text === "") { grid.moveCurrentIndexLeft();  event.accepted = true }
                                break
                            case Qt.Key_Return:
                            case Qt.Key_Enter:
                                root.pickCurrent(); event.accepted = true; break
                            case Qt.Key_Tab:
                                root.cycleCategory(1); event.accepted = true; break
                            case Qt.Key_Backtab:
                                root.cycleCategory(-1); event.accepted = true; break
                            }
                        }
                    }
                }
            }
        }

        // ── Category strip ─────────────────────────────────────────────────────
        TabSwitcher {
            width:  parent.width
            height: 40
            model:  root.tabs
            currentPage: root.category === -1 ? "recent" : String(root.category)
            onPageChanged: function (key) {
                root.category = key === "recent" ? -1 : parseInt(key)
                if (root.searching) {
                    root.searchQuery = ""
                    searchInput.text = ""
                }
            }
        }

        // ── Grid ───────────────────────────────────────────────────────────────
        Item {
            width:  parent.width
            height: parent.height - 45 - 36 - 40 - 22

            // Empty states
            Column {
                anchors.centerIn: parent; spacing: 10
                visible: root.results.length === 0
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: String.fromCodePoint(0xF01F5)   // nf-md-emoticon
                    font.pixelSize: 32; color: Qt.rgba(1,1,1,0.08)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.searching ? "No emoji found" : "No recent emoji"
                    font.pixelSize: 12; color: Qt.rgba(1,1,1,0.20)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.searching ? "Try another word" : "Pick one to start the list"
                    font.pixelSize: 10; color: Qt.rgba(1,1,1,0.13)
                }
            }

            GridView {
                id: grid
                anchors {
                    fill:         parent
                    topMargin:    6
                    leftMargin:   2
                    rightMargin:  12
                    bottomMargin: 4
                }
                clip:           true
                boundsBehavior: Flickable.StopAtBounds
                visible:        root.results.length > 0
                model:          root.results

                cellWidth:  Math.floor(width / 9)
                cellHeight: cellWidth

                ScrollBar.vertical: vbar

                highlightMoveDuration: 130
                highlight: Rectangle {
                    radius: 9
                    color:  Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.20)
                    border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.38)
                    border.width: 1
                }

                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index

                    width:  grid.cellWidth
                    height: grid.cellHeight

                    Rectangle {
                        anchors.centerIn: parent
                        width:  grid.cellWidth  - 4
                        height: grid.cellHeight - 4
                        radius: 9
                        color:  cellHov.hovered ? Qt.rgba(1, 1, 1, 0.09) : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text:           cell.modelData.c
                            font.family:    "Noto Color Emoji"
                            font.pixelSize: 22

                            scale: cellHov.hovered ? 1.18 : 1.0
                            Behavior on scale {
                                NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    HoverHandler {
                        id: cellHov
                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: {
                            if (hovered) {
                                grid.currentIndex = cell.index
                                root.hoverName    = cell.modelData.n
                            } else if (root.hoverName === cell.modelData.n) {
                                root.hoverName = ""
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: EmojiService.pick(cell.modelData.c)
                    }
                }
            }

            // External scrollbar at the absolute edge, as in the clipboard popup
            ScrollBar {
                id: vbar
                anchors {
                    top:    parent.top
                    bottom: parent.bottom
                    right:  parent.right
                    topMargin: 6
                    bottomMargin: 4
                }
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    implicitWidth:  4
                    implicitHeight: 10
                    radius:         2
                    color:          Qt.rgba(1, 1, 1, 0.22)
                }
            }
        }

        // ── Footer ─────────────────────────────────────────────────────────────
        Item {
            width:  parent.width
            height: 22

            Text {
                anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                width: parent.width - hint.implicitWidth - 20
                text: root.hoverName !== "" ? root.hoverName : root.currentName
                font.pixelSize: 10
                color: Qt.rgba(1, 1, 1, 0.35)
                elide: Text.ElideRight
            }

            Text {
                id: hint
                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                text: "⏎ insert"
                font.pixelSize: 10
                color: Qt.rgba(1, 1, 1, 0.20)
            }
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    readonly property string currentName:
        grid.currentIndex >= 0 && grid.currentIndex < root.results.length
            ? root.results[grid.currentIndex].n
            : ""

    function pickCurrent() {
        if (grid.currentIndex < 0 || grid.currentIndex >= root.results.length) return
        EmojiService.pick(root.results[grid.currentIndex].c)
    }

    function cycleCategory(step) {
        var count = EmojiService.categories.length
        if (count === 0) return

        // -1 (recents) sits before category 0 in the strip.
        var next = root.category + step
        if (next < -1)      next = count - 1
        if (next >= count)  next = -1
        root.category = next
    }
}
