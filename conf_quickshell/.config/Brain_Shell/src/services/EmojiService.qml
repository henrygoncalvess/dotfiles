pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// ─────────────────────────────────────────────────────────────
// EmojiService — catalogue, search and picking for the emoji popup.
//
// The catalogue lives in src/data/emoji.json, generated from the Unicode
// emoji-test.txt by src/scripts/gen_emoji_data.py, so nothing is fetched at
// runtime. Recently picked emoji persist in src/user_data/emoji_recents.json.
// ─────────────────────────────────────────────────────────────

QtObject {
    id: root

    // Category names. An entry's `g` field indexes into this list.
    property var categories: []

    // Catalogue entries: { c: character, n: name, g: category, k: keywords }
    property var entries: []

    // Recently picked characters, newest first.
    property var recents: []

    property bool ready: false

    readonly property int recentsLimit: 36

    readonly property string _recentsPath:
        Quickshell.shellPath("src/user_data/emoji_recents.json")

    // ── Catalogue ─────────────────────────────────────────────────────────────
    property var _dataFile: FileView {
        id: dataFile
        path: Quickshell.shellPath("src/data/emoji.json")
        watchChanges: false
        onLoaded: root._parseCatalogue(dataFile.text())
        onLoadFailed: console.error("Brain Shell: could not read " + dataFile.path)
    }

    function _parseCatalogue(raw) {
        if (!raw || raw.trim() === "") return
        try {
            var data = JSON.parse(raw)
            root.categories = data.groups ?? []
            root.entries    = data.emojis ?? []
            root.ready      = root.entries.length > 0
        } catch (e) {
            console.error("Brain Shell: malformed emoji.json — " + e)
        }
    }

    // ── Recents ───────────────────────────────────────────────────────────────
    property var _recentsFile: FileView {
        id: recentsFile
        path: root._recentsPath
        watchChanges: false
        onLoaded: root._parseRecents(recentsFile.text())
        // Missing file just means nothing has been picked yet.
        onLoadFailed: root.recents = []
    }

    function _parseRecents(raw) {
        if (!raw || raw.trim() === "") return
        try {
            var list = JSON.parse(raw)
            if (Array.isArray(list)) root.recents = list.slice(0, root.recentsLimit)
        } catch (e) {
            root.recents = []
        }
    }

    property var _saveRecentsProc: Process { command: []; running: false }

    function _saveRecents() {
        _saveRecentsProc.command = ["bash", "-c",
            "mkdir -p \"$(dirname '" + root._recentsPath + "')\" && " +
            "printf '%s' '" + JSON.stringify(root.recents) + "' > '" + root._recentsPath + "'"]
        _saveRecentsProc.running = false
        _saveRecentsProc.running = true
    }

    function _remember(ch) {
        var list = root.recents.filter(function (c) { return c !== ch })
        list.unshift(ch)
        root.recents = list.slice(0, root.recentsLimit)
        root._saveRecents()
    }

    function clearRecents() {
        root.recents = []
        root._saveRecents()
    }

    // ── Lookup ────────────────────────────────────────────────────────────────
    // Character → entry, rebuilt whenever the catalogue changes.
    readonly property var _byChar: {
        var map = {}
        for (var i = 0; i < root.entries.length; i++)
            map[root.entries[i].c] = root.entries[i]
        return map
    }

    function entryFor(ch) {
        return root._byChar[ch] ?? { c: ch, n: "", g: -1, k: "" }
    }

    // ── Results ───────────────────────────────────────────────────────────────
    // A query searches the whole catalogue and ignores the category, which is
    // what every other picker does. An empty query lists the category, with
    // category -1 meaning the recents.
    function results(query, category) {
        var q = (query ?? "").trim().toLowerCase()

        if (q === "") {
            if (category < 0)
                return root.recents.map(function (c) { return root.entryFor(c) })

            return root.entries.filter(function (e) { return e.g === category })
        }

        // Ranked: name prefix first, then name substring, then keywords.
        var prefix = []
        var inName = []
        var inKeys = []

        for (var i = 0; i < root.entries.length; i++) {
            var e   = root.entries[i]
            var pos = e.n.indexOf(q)

            if (pos === 0)          prefix.push(e)
            else if (pos > 0)       inName.push(e)
            else if (e.k.indexOf(q) >= 0) inKeys.push(e)
        }

        return prefix.concat(inName, inKeys)
    }

    // ── Picking ───────────────────────────────────────────────────────────────
    // A pick lands on the clipboard and is then inserted into whatever window
    // had focus, so clicking an emoji is enough — no manual paste.
    function pick(ch) {
        if (!ch || ch === "") return

        ClipboardService.copyText(ch)
        root._remember(ch)
        Popups.emojiOpen = false
        ClipboardService.typeFromClipboard()
    }
}
