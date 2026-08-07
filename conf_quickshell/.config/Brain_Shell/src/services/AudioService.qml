pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../"

QtObject {
    id: root

    readonly property string backend: Quickshell.shellDir + "/src/scripts/audio-control.sh"

    property var state: ({
        ok: false,
        sinks: [],
        sources: [],
        cards: [],
        playback: [],
        recording: [],
        effects: ({ available: false, installed: false, running: false, enabled: false, invalidDefault: false, preset: "" })
    })
    property bool loading: false
    property bool busy: false
    property bool refreshPending: false
    property bool panelVisible: false
    property string notice: ""
    property bool noticeIsError: false

    readonly property var sinks: state.sinks ?? []
    readonly property var sources: state.sources ?? []
    readonly property var cards: state.cards ?? []
    readonly property var effects: state.effects ?? ({})
    readonly property var playbackRoutes: state.playback ?? []
    readonly property var recordingRoutes: state.recording ?? []
    readonly property int orphanCount: {
        var count = 0
        for (const stream of playbackRoutes)
            if (stream.orphaned) count++
        for (const stream of recordingRoutes)
            if (stream.orphaned) count++
        return count
    }

    function isEffectStream(node) {
        const properties = node?.properties ?? ({})
        const id = String(properties["application.id"] || "").toLowerCase()
        const name = String(properties["application.name"] || node?.name || "").toLowerCase()
        return id === "com.github.wwmm.easyeffects" || name.includes("easyeffects") || name.includes("easy effects")
    }

    function isMeterStream(node) {
        const properties = node?.properties ?? ({})
        const app = String(properties["application.name"] || "").toLowerCase()
        const media = String(properties["media.name"] || "").toLowerCase()
        return app === "quickshell peak detect" || media === "peak detect"
    }

    property var _tracker: PwObjectTracker {
        // Track first, then filter streams for presentation. Filtering this
        // list by node properties creates a dependency cycle when a peak
        // monitor is added to the PipeWire graph.
        objects: Pipewire.nodes.values
    }

    readonly property var playbackStreams: {
        const result = []
        const nodes = Pipewire.nodes.values
        for (let i = 0; i < nodes.length; i++) {
            const node = nodes[i]
            // Quickshell 0.3 marks Pulse sink-input/playback streams as sinks.
            // This was verified against the same stream in pactl's sink-inputs.
            if (node.isStream && node.isSink && node.audio !== null &&
                    !isEffectStream(node) && !isMeterStream(node))
                result.push(node)
        }
        return result
    }

    readonly property var recordingStreams: {
        const result = []
        const nodes = Pipewire.nodes.values
        for (let i = 0; i < nodes.length; i++) {
            const node = nodes[i]
            // Pulse source-output/capture streams are the non-sink side here.
            if (node.isStream && !node.isSink && node.audio !== null &&
                    !isEffectStream(node) && !isMeterStream(node))
                result.push(node)
        }
        return result
    }

    readonly property var outputNode: nodeByName(state.selectedSink ?? "")
    readonly property var inputNode: nodeByName(state.selectedSource ?? "")

    // Peak monitors read the real PipeWire signal, not the configured volume.
    // Keep them off while the panel is closed to avoid permanent capture nodes.
    property var outputPeakMonitor: PwNodePeakMonitor {
        node: root.outputNode
        enabled: root.panelVisible && root.outputNode !== null
    }

    property var inputPeakMonitor: PwNodePeakMonitor {
        node: root.inputNode
        enabled: root.panelVisible && root.inputNode !== null
    }

    readonly property real outputPeak: outputPeakMonitor.enabled && Number.isFinite(outputPeakMonitor.peak)
                                               ? Math.max(0, outputPeakMonitor.peak) : 0
    readonly property real inputPeak: inputPeakMonitor.enabled && Number.isFinite(inputPeakMonitor.peak)
                                              ? Math.max(0, inputPeakMonitor.peak) : 0

    function nodeByName(name) {
        if (!name) return null
        const nodes = Pipewire.nodes.values
        for (let i = 0; i < nodes.length; i++)
            if (nodes[i].name === name) return nodes[i]
        return null
    }

    function selectedSink() {
        for (const device of sinks)
            if (device.isSelected) return device
        return sinks.length > 0 ? sinks[0] : null
    }

    function selectedSource() {
        for (const device of sources)
            if (device.isSelected) return device
        return sources.length > 0 ? sources[0] : null
    }

    function streamSerial(node) {
        const properties = node?.properties ?? ({})
        return String(properties["object.serial"] ?? "")
    }

    function streamName(node) {
        const properties = node?.properties ?? ({})
        return properties["application.name"] || node?.description || node?.name || "Application"
    }

    function streamMedia(node) {
        const properties = node?.properties ?? ({})
        const media = properties["media.name"] || ""
        const normalized = String(media).toLowerCase()
        if (normalized.startsWith("alsa_") || normalized.startsWith("easyeffects")) return ""
        return media === streamName(node) ? "" : media
    }

    function streamIcon(node) {
        const properties = node?.properties ?? ({})
        const role = String(properties["media.role"] || "").toLowerCase()
        if (role === "video") return "󰕧"
        if (role === "game") return "󰊴"
        if (role === "phone" || role === "communication") return "󰏲"
        return "󰎆"
    }

    function streamRoute(node) {
        const serial = streamSerial(node)
        for (const route of playbackRoutes)
            if (String(route.index) === serial) return route
        return null
    }

    function recordingRoute(node) {
        const serial = streamSerial(node)
        for (const route of recordingRoutes)
            if (String(route.index) === serial) return route
        return null
    }

    function endpointIcon(kind, muted) {
        if (muted) return kind === "microphone" ? "󰍭" : "󰖁"
        if (kind === "speaker") return "󰓃"
        if (kind === "headphones") return "󰋋"
        if (kind === "display") return "󰍹"
        if (kind === "bluetooth") return "󰂯"
        if (kind === "usb") return "󰕓"
        if (kind === "microphone") return "󰍬"
        return "󰕾"
    }

    function profileHint(profile) {
        switch (profile?.kind) {
        case "duplex": return "Keeps sound and microphone available at the same time."
        case "output": return "Plays sound, but disables this card's input."
        case "input": return "Uses the microphone, but disables this card's output."
        case "pro": return "Raw channels for DAWs. This may interrupt application audio."
        case "off": return "Completely disables this audio card."
        default: return profile?.description ?? ""
        }
    }

    function profilesFor(card, includeTechnical) {
        const result = []
        const profiles = card?.profiles ?? []
        for (const profile of profiles) {
            const technical = profile.kind === "pro" || profile.kind === "off"
            if (!technical || includeTechnical) result.push(profile)
        }
        return result
    }

    function refresh() {
        if (snapshotProcess.running || actionProcess.running) {
            refreshPending = true
            return
        }
        refreshPending = false
        loading = true
        snapshotProcess.running = true
    }

    function runAction(actionArguments, pendingText) {
        if (busy || actionProcess.running) return
        busy = true
        notice = pendingText || "Applying…"
        noticeIsError = false
        actionProcess.command = [backend].concat(actionArguments)
        actionProcess.running = true
    }

    function chooseOutput(device) {
        if (device?.name) runAction(["set-output", device.name], "Changing output…")
    }

    function chooseInput(device) {
        if (device?.name) runAction(["set-input", device.name], "Changing microphone…")
    }

    function chooseOutputPort(device, port) {
        if (device?.name && port?.name)
            runAction(["set-output-port", device.name, port.name], "Changing connector…")
    }

    function chooseInputPort(device, port) {
        if (device?.name && port?.name)
            runAction(["set-input-port", device.name, port.name], "Changing connector…")
    }

    function chooseProfile(card, profile) {
        if (card?.name && profile?.key)
            runAction(["set-profile", card.name, profile.key], "Changing card mode…")
    }

    function moveStream(node, sink) {
        const serial = streamSerial(node)
        if (serial && sink?.name)
            runAction(["move-app", serial, sink.name], "Moving application…")
    }

    function setEffects(enabled) {
        runAction(["effects", enabled ? "on" : "off"],
                  enabled ? "Turning effects on…" : "Turning effects off…")
    }

    function repair() {
        runAction(["repair"], "Restoring audio routes…")
    }

    property var snapshotProcess: Process {
        id: snapshotProcess
        command: [root.backend, "snapshot"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text)
                    if (parsed.ok) {
                        root.state = parsed
                    } else {
                        root.notice = parsed.message || "Could not read audio state"
                        root.noticeIsError = true
                    }
                } catch (error) {
                    root.notice = "Invalid response from the audio service"
                    root.noticeIsError = true
                }
            }
        }

        onRunningChanged: {
            if (!running) {
                root.loading = false
                if (root.refreshPending && !actionProcess.running)
                    Qt.callLater(root.refresh)
            }
        }
    }

    property var actionProcess: Process {
        id: actionProcess
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text)
                    root.notice = parsed.message || (parsed.ok ? "Done" : "Could not apply the change")
                    root.noticeIsError = !parsed.ok
                } catch (error) {
                    root.notice = "The audio action did not respond correctly"
                    root.noticeIsError = true
                }
            }
        }

        onRunningChanged: {
            if (!running) {
                root.busy = false
                refreshAfterAction.restart()
                noticeTimer.restart()
            }
        }
    }

    // React to real graph changes instead of running a permanent polling loop.
    // Client-only events are ignored so our own snapshot commands do not cause
    // a feedback loop.
    property var subscriptionProcess: Process {
        id: subscriptionProcess
        command: ["pactl", "subscribe"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                if (/on (sink|source|card|sink-input|source-output|server) #/.test(line))
                    graphDebounce.restart()
            }
        }
        onRunningChanged: if (!running) subscriptionRestart.restart()
    }

    property var graphDebounce: Timer {
        id: graphDebounce
        interval: 220
        onTriggered: root.refresh()
    }

    property var refreshAfterAction: Timer {
        id: refreshAfterAction
        interval: 300
        onTriggered: root.refresh()
    }

    property var subscriptionRestart: Timer {
        id: subscriptionRestart
        interval: 3000
        onTriggered: if (!subscriptionProcess.running) subscriptionProcess.running = true
    }

    property var noticeTimer: Timer {
        id: noticeTimer
        interval: 4200
        onTriggered: if (!root.busy) root.notice = ""
    }

    Component.onCompleted: refresh()
}
