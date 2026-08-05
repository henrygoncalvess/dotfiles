import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../components"
import "../"

Item {
    id: root

    readonly property var sink:   Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    // Sink que o slider de volume realmente controla.
    //
    // Com o EasyEffects roteando o áudio, o default sink vira easyeffects_sink —
    // um node virtual. O PipeWire aceita e guarda o channelVolumes dele, mas não
    // existe mixer por trás pra aplicar: dá pra deixar o node em 10% que o som
    // continua no mesmo volume. O slider ficava mexendo num controle morto.
    //
    // Volume de verdade só no dispositivo real que o EE alimenta, então quando o
    // default for o sink virtual a gente cai pro primeiro sink físico.
    readonly property var volumeSink: {
        var d = Pipewire.defaultAudioSink
        if (!d || d.name !== "easyeffects_sink") return d
        var nodes = root.sinkNodes
        for (var i = 0; i < nodes.length; i++)
            if (nodes[i].name !== "easyeffects_sink") return nodes[i]
        return d
    }

    // Teto dos sliders. O PipeWire aceita ganho acima de 0 dB; o pavucontrol
    // deixa ir até 150%, então aqui também.
    readonly property real maxVolume: 1.5

    function reset() { switcher.reset() }

    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    readonly property var sinkNodes: {
        var result = []
        var nodes = Pipewire.nodes.values
        for (var i = 0; i < nodes.length; i++) {
            var n = nodes[i]
            if (n.audio !== null && !n.isStream && n.isSink)
                result.push(n)
        }
        return result
    }

    readonly property var sourceNodes: {
        var result = []
        var nodes = Pipewire.nodes.values
        for (var i = 0; i < nodes.length; i++) {
            var n = nodes[i]
            if (n.audio !== null && !n.isStream && !n.isSink)
                result.push(n)
        }
        return result
    }

    readonly property var playbackStreamNodes: {
        var result = []
        var nodes = Pipewire.nodes.values
        for (var i = 0; i < nodes.length; i++) {
            var n = nodes[i]
            if (n.audio !== null && n.isStream && n.isSink)
                result.push(n)
        }
        return result
    }

    readonly property var recordStreamNodes: {
        var result = []
        var nodes = Pipewire.nodes.values
        for (var i = 0; i < nodes.length; i++) {
            var n = nodes[i]
            if (n.audio !== null && n.isStream && !n.isSink)
                result.push(n)
        }
        return result
    }

    function deviceName(node) {
        if (!node) return "Unknown"
        return node.nickname || node.description || node.name || "Unknown"
    }

    // ── Streams de aplicativo ────────────────────────────────────────────────
    // node.description num stream costuma ser genérico ("Playback"); o nome que
    // o usuário reconhece está em application.name, e a faixa em media.name.
    function streamAppName(node) {
        if (!node) return "Unknown"
        const p = node.properties ?? ({})
        return p["application.name"] || node.description || node.name || "Unknown"
    }

    function streamMediaName(node) {
        const p = node?.properties ?? ({})
        const media = p["media.name"] || ""
        return media === streamAppName(node) ? "" : media
    }

    function streamIcon(node) {
        const p = node?.properties ?? ({})
        const role = (p["media.role"] || "").toLowerCase()
        if (role === "music")   return "󰎆"
        if (role === "video")   return "󰕧"
        if (role === "game")    return "󰊴"
        if (role === "phone")   return "󰏲"
        return "󰎆"
    }

    // O pactl indexa sink-inputs por object.serial — conferido: "Sink Input #381"
    // corresponde a object.serial=381. O PwNode.id é o id global do PipeWire e
    // NÃO serve aqui (mover pelo id move o alvo errado ou o default global).
    function streamSerial(node) {
        const p = node?.properties ?? ({})
        return p["object.serial"] ?? ""
    }

    // Roteia um app pra outra saída, igual ao seletor de dispositivo por
    // aplicativo do pavucontrol.
    function moveStream(node, sinkName) {
        const serial = streamSerial(node)
        if (!serial || !sinkName) return
        Quickshell.execDetached(["pactl", "move-sink-input", String(serial), sinkName])
        routeRefresh.restart()
    }

    // serial do stream → nome do sink em que ele toca agora. O PwNode não expõe
    // esse vínculo, então vem do pactl.
    property var streamRoutes: ({})

    Process {
        id: routeProbe
        command: ["pactl", "-f", "json", "list", "sink-inputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    const map = {}
                    for (const si of data) {
                        const serial = si.properties?.["object.serial"]
                        if (serial !== undefined) map[String(serial)] = si.sink
                    }
                    root.streamRoutes = map
                } catch (e) {
                    root.streamRoutes = ({})
                }
            }
        }
    }

    // Nome do sink onde o stream está tocando (índice numérico → nome do node).
    function streamSinkName(node) {
        const target = root.streamRoutes[String(streamSerial(node))]
        if (target === undefined) return ""
        for (const s of root.sinkNodes) {
            if (String(s.id) === String(target) || s.name === target)
                return root.deviceName(s)
        }
        return String(target)
    }

    // ── Perfis de placa (aba Config) ─────────────────────────────────────────
    // Equivalente à aba "Configuration" do pavucontrol: troca o perfil da placa
    // (analog stereo, HDMI, duplex…), que é o que habilita/desabilita saídas.
    property var cards: []

    Process {
        id: cardProbe
        command: ["pactl", "-f", "json", "list", "cards"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    root.cards = data.map(c => ({
                        name:     c.name,
                        pretty:   c.properties?.["device.description"] || c.name,
                        active:   c.active_profile,
                        profiles: Object.keys(c.profiles ?? {})
                            .filter(k => (c.profiles[k]?.available ?? true))
                            .map(k => ({ key: k, desc: c.profiles[k]?.description || k }))
                    }))
                } catch (e) {
                    root.cards = []
                }
            }
        }
    }

    function setCardProfile(cardName, profileKey) {
        Quickshell.execDetached(["pactl", "set-card-profile", cardName, profileKey])
        cardRefresh.restart()
    }

    Timer { id: routeRefresh; interval: 250; onTriggered: routeProbe.running = true }
    Timer { id: cardRefresh;  interval: 250; onTriggered: cardProbe.running  = true }

    // Só consulta o pactl enquanto o popup está aberto — sem polling de fundo.
    Timer {
        interval: 2000
        repeat:   true
        running:  Popups.audioOpen
        triggeredOnStart: true
        onTriggered: {
            routeProbe.running = true
            if (root.page === "config") cardProbe.running = true
        }
    }

    property string page: Popups.audioPage

    Connections {
        target: Popups
        function onAudioPageChanged() {
            root.page = Popups.audioPage
            if (root.page === "config") cardProbe.running = true
        }
    }

    Row {
        anchors.fill: parent
        spacing: 8

        // ── Page content ──────────────────────────────────────────────────────
        Item {
            width:  parent.width - switcher.implicitWidth - parent.spacing - 1 - parent.spacing
            height: parent.height
            clip:   true

            // Output
            Item {
                anchors.fill: parent
                visible:      root.page === "output"

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    SectionLabel { text: "Master Output" }

                    HorizontalSlider {
                        Layout.fillWidth: true
                        label:  (root.volumeSink && root.volumeSink.ready) ? root.deviceName(root.volumeSink) : "Output"
                        icon: {
                            if (!root.volumeSink || !root.volumeSink.ready) return "󰕾"
                            if (root.volumeSink.audio.muted) return "󰖁"
                            if (root.volumeSink.audio.volume > 0.6) return "󰕾"
                            if (root.volumeSink.audio.volume > 0.2) return "󰖀"
                            return "󰕿"
                        }
                        value:  (root.volumeSink && root.volumeSink.ready) ? root.volumeSink.audio.volume : 0
                        muted:  (root.volumeSink && root.volumeSink.audio) ? root.volumeSink.audio.muted : false
                        active: (root.volumeSink && root.volumeSink.ready) || false
                        maxValue: root.maxVolume
                        onVolumeChanged: function(v) {
                            if (root.volumeSink && root.volumeSink.ready) root.volumeSink.audio.volume = v
                        }
                        onMuteToggled: {
                            if (root.volumeSink && root.volumeSink.ready)
                                root.volumeSink.audio.muted = !root.volumeSink.audio.muted
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Qt.rgba(1, 1, 1, 0.06)
                    }

                    SectionLabel { text: "Applications" }

                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentHeight: streamsCol.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: streamsCol
                            width: parent.width
                            spacing: 6

                            Repeater {
                                model: root.playbackStreamNodes
                                delegate: HorizontalSlider {
                                    width: streamsCol.width
                                    label: root.streamAppName(modelData)
                                    sublabel: root.streamMediaName(modelData)
                                    icon: root.streamIcon(modelData)
                                    value: modelData.audio.volume
                                    muted: modelData.audio.muted
                                    active: true
                                    maxValue: root.maxVolume
                                    // Seletor de saída por app (como o pavucontrol)
                                    routeTargets: root.sinkNodes
                                    routeCurrent: root.streamSinkName(modelData)
                                    onRoutePicked: function(sinkNode) {
                                        root.moveStream(modelData, sinkNode.name)
                                    }
                                    onVolumeChanged: function(v) { modelData.audio.volume = v }
                                    onMuteToggled: { modelData.audio.muted = !modelData.audio.muted }
                                }
                            }
                            
                            Text {
                                visible: root.playbackStreamNodes.length === 0
                                text: "No apps playing audio"
                                color: Qt.rgba(1,1,1,0.2)
                                font.pixelSize: 11
                                leftPadding: 10
                            }
                        }
                    }
                }
            }

            // Input
            Item {
                anchors.fill: parent
                visible:      root.page === "input"

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    SectionLabel { text: "Master Input" }

                    HorizontalSlider {
                        Layout.fillWidth: true
                        label:  (root.source && root.source.ready) ? root.deviceName(root.source) : "Input"
                        icon:   (root.source && root.source.audio && root.source.audio.muted) ? "󰍭" : "󰍬"
                        value:  (root.source && root.source.ready) ? root.source.audio.volume : 0
                        muted:  (root.source && root.source.audio) ? root.source.audio.muted : false
                        active: (root.source && root.source.ready) || false
                        maxValue: root.maxVolume
                        onVolumeChanged: function(v) {
                            if (root.source && root.source.ready) root.source.audio.volume = v
                        }
                        onMuteToggled: {
                            if (root.source && root.source.ready)
                                root.source.audio.muted = !root.source.audio.muted
                        }
                    }
                    
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Qt.rgba(1, 1, 1, 0.06)
                    }

                    SectionLabel { text: "Applications" }

                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentHeight: recordCol.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: recordCol
                            width: parent.width
                            spacing: 6

                            Repeater {
                                model: root.recordStreamNodes
                                delegate: HorizontalSlider {
                                    width: recordCol.width
                                    label: root.deviceName(modelData)
                                    icon: "󰍬"
                                    value: modelData.audio.volume
                                    muted: modelData.audio.muted
                                    active: true
                                    onVolumeChanged: function(v) { modelData.audio.volume = v }
                                    onMuteToggled: { modelData.audio.muted = !modelData.audio.muted }
                                }
                            }
                            
                            Text {
                                visible: root.recordStreamNodes.length === 0
                                text: "No apps recording audio"
                                color: Qt.rgba(1,1,1,0.2)
                                font.pixelSize: 11
                                leftPadding: 10
                            }
                        }
                    }
                }
            }

            // Mixer
            Item {
                anchors.fill: parent
                visible:      root.page === "mixer"

                Flickable {
                    anchors.fill: parent
                    contentHeight: mixerCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: mixerCol
                        width: parent.width
                        spacing: 8

                        SectionLabel { text: "Output Devices" }

                        Repeater {
                            model: root.sinkNodes
                            delegate: HorizontalSlider {
                                width: mixerCol.width
                                label: root.deviceName(modelData)
                                icon: "󰕾"
                                value: modelData.audio.volume
                                muted: modelData.audio.muted
                                isDefault: (root.sink && root.sink.ready && modelData.name === root.sink.name) || false
                                active: true
                                showDefaultButton: true
                                maxValue: root.maxVolume
                                onVolumeChanged: function(v) { modelData.audio.volume = v }
                                onMuteToggled: { modelData.audio.muted = !modelData.audio.muted }
                                onSetDefault: { Pipewire.preferredDefaultAudioSink = modelData }
                            }
                        }

                        Text {
                            visible: root.sinkNodes.length === 0
                            text: "No output devices"
                            color: Qt.rgba(1,1,1,0.2)
                            font.pixelSize: 11
                            leftPadding: 10
                        }

                        Rectangle {
                            width: parent.width; height: 1
                            color: Qt.rgba(1, 1, 1, 0.06)
                        }

                        SectionLabel { text: "Input Devices" }

                        Repeater {
                            model: root.sourceNodes
                            delegate: HorizontalSlider {
                                width: mixerCol.width
                                label: root.deviceName(modelData)
                                icon: "󰍬"
                                value: modelData.audio.volume
                                muted: modelData.audio.muted
                                isDefault: (root.source && root.source.ready && modelData.name === root.source.name) || false
                                active: true
                                showDefaultButton: true
                                maxValue: root.maxVolume
                                onVolumeChanged: function(v) { modelData.audio.volume = v }
                                onMuteToggled: { modelData.audio.muted = !modelData.audio.muted }
                                onSetDefault: { Pipewire.preferredDefaultAudioSource = modelData }
                            }
                        }

                        Text {
                            visible: root.sourceNodes.length === 0
                            text: "No input devices"
                            color: Qt.rgba(1,1,1,0.2)
                            font.pixelSize: 11
                            leftPadding: 10
                        }
                    }
                }
            }

            // Config — perfis de placa (aba "Configuration" do pavucontrol)
            Item {
                anchors.fill: parent
                visible:      root.page === "config"

                Flickable {
                    anchors.fill: parent
                    contentHeight: cardsCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: cardsCol
                        width: parent.width
                        spacing: 8

                        SectionLabel { text: "Card Profiles" }

                        Repeater {
                            model: root.cards
                            delegate: Column {
                                id: cardEntry
                                required property var modelData
                                // Alias nomeado: o Repeater de dentro declara o
                                // próprio modelData e sombrearia este.
                                readonly property var card: modelData

                                width: cardsCol.width
                                spacing: 4

                                Text {
                                    text: cardEntry.card.pretty
                                    color: Theme.text
                                    font.pixelSize: 11
                                    font.bold: true
                                    elide: Text.ElideRight
                                    width: parent.width
                                    leftPadding: 4
                                }

                                Repeater {
                                    model: cardEntry.card.profiles
                                    delegate: Rectangle {
                                        id: profRow
                                        required property var modelData
                                        readonly property bool isActive:
                                            modelData.key === cardEntry.card.active

                                        width:  cardsCol.width
                                        height: 28
                                        radius: Theme.cornerRadius - 4
                                        color: profRow.isActive
                                               ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.15)
                                               : (profHover.hovered ? Qt.rgba(1,1,1,0.08) : "transparent")

                                        Text {
                                            anchors.left:           parent.left
                                            anchors.leftMargin:     12
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 40
                                            text:  profRow.modelData.desc
                                            color: profRow.isActive ? Theme.text : Qt.rgba(1,1,1,0.65)
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            anchors.right:          parent.right
                                            anchors.rightMargin:    10
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: profRow.isActive
                                            text:    "✓"
                                            color:   Theme.active
                                            font.pixelSize: 11
                                            font.bold: true
                                        }

                                        HoverHandler { id: profHover; cursorShape: Qt.PointingHandCursor }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: root.setCardProfile(
                                                cardEntry.card.name, profRow.modelData.key)
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            visible: root.cards.length === 0
                            text: "No sound cards found"
                            color: Qt.rgba(1,1,1,0.2)
                            font.pixelSize: 11
                            leftPadding: 10
                        }
                    }
                }
            }
        }

        // Divider
        Rectangle {
            width: 1; height: parent.height
            color: Qt.rgba(1, 1, 1, 0.1)
        }

        // Tab switcher — right side
        TabSwitcher {
            id: switcher
            orientation: "vertical"
            height: (parent.height - 17)
            anchors.verticalCenter: parent.verticalCenter
            model: [
                { key: "output", icon: "󰕾" },
                { key: "input",  icon: "󰍬" },
                { key: "mixer",  icon: "󰾝" },
                { key: "config", icon: "󰢻" },
            ]
            currentPage: root.page
            onPageChanged: function(key) { Popups.audioPage = key }
        }
    }

    // ── HorizontalSlider ─────────────────────────────────────────────────────────
    component HorizontalSlider: Item {
        id: comp
        property string label: ""
        property string sublabel: ""      // faixa/mídia tocando, quando houver
        property string icon: ""
        property real value: 0.0
        property bool muted: false
        property bool isDefault: false
        property bool active: false
        property bool showDefaultButton: false

        // Teto do slider. 1.0 = 100%; sinks e streams usam 1.5 pra permitir boost.
        property real maxValue: 1.0

        // Seletor de saída por app: lista de PwNode de sink pra onde este stream
        // pode ir. Vazio = não mostra o seletor (dispositivos não se "movem").
        property var    routeTargets: []
        property string routeCurrent: ""
        signal routePicked(var sinkNode)

        signal volumeChanged(real value)
        signal muteToggled()
        signal setDefault()

        readonly property bool hasRouting: routeTargets && routeTargets.length > 1
        property bool routeOpen: false

        implicitHeight: 46 + (routeOpen ? routeList.implicitHeight + 6 : 0)
        Behavior on implicitHeight { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        readonly property string pctText: active ? Math.round(value * 100) + "%" : "--%"

        Rectangle {
            anchors.fill: parent
            radius: Theme.cornerRadius - 4
            color: comp.isDefault ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.12) : "transparent"
        }

        RowLayout {
            id: mainRow
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.top:    parent.top
            anchors.margins: 6
            height: 46 - 12
            spacing: 8

            // Mute / Icon Button
            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 16
                color: comp.muted ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.2) : Qt.rgba(1,1,1,0.06)

                Text {
                    anchors.centerIn: parent
                    text: comp.icon
                    font.pixelSize: 14
                    color: comp.muted ? Theme.active : Qt.rgba(1,1,1,0.55)
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: comp.muteToggled()
                    cursorShape: Qt.PointingHandCursor
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: comp.label
                        color: Theme.text
                        font.pixelSize: 11
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    // Faixa/mídia tocando — só aparece pra streams de app.
                    Text {
                        visible: comp.sublabel !== ""
                        text:    comp.sublabel
                        color:   Qt.rgba(1,1,1,0.35)
                        font.pixelSize: 9
                        elide:   Text.ElideRight
                        Layout.maximumWidth: 110
                    }

                    // Seletor de saída (pavucontrol-style): abre a lista de sinks.
                    Rectangle {
                        visible: comp.hasRouting
                        Layout.preferredWidth:  18
                        Layout.preferredHeight: 14
                        radius: 4
                        color: comp.routeOpen || routeHover.hovered
                               ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35)
                               : Qt.rgba(1,1,1,0.1)

                        Text {
                            anchors.centerIn: parent
                            text:  "󰓃"
                            color: comp.routeOpen ? Theme.active : Qt.rgba(1,1,1,0.5)
                            font.pixelSize: 9
                        }

                        HoverHandler { id: routeHover; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: comp.routeOpen = !comp.routeOpen
                        }
                    }

                    Rectangle {
                        visible: comp.showDefaultButton && !comp.isDefault
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 14
                        radius: 4
                        color: defaultHover.hovered ? Theme.active : Qt.rgba(1,1,1,0.1)
                        
                        Text {
                            anchors.centerIn: parent
                            text: "✓"
                            color: defaultHover.hovered ? "#fff" : Qt.rgba(1,1,1,0.5)
                            font.pixelSize: 10
                        }
                        
                        HoverHandler { id: defaultHover; cursorShape: Qt.PointingHandCursor }
                        MouseArea { anchors.fill: parent; onClicked: comp.setDefault() }
                    }
                    
                    Text {
                        text: "Default"
                        visible: comp.isDefault
                        color: Theme.active
                        font.pixelSize: 9
                        font.bold: true
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 8
                    
                    Rectangle {
                        id: track
                        anchors.fill: parent
                        radius: 4
                        color: Qt.rgba(1,1,1,0.08)

                        // Marca dos 100% quando o slider vai além (boost)
                        Rectangle {
                            visible: comp.maxValue > 1.0
                            x:       parent.width * (1.0 / comp.maxValue) - 1
                            width:   1
                            height:  parent.height
                            color:   Qt.rgba(1,1,1,0.25)
                        }

                        Rectangle {
                            height: parent.height
                            width: Math.max(parent.radius * 2,
                                            parent.width * (comp.value / comp.maxValue))
                            radius: parent.radius
                            // Acima de 100% o preenchimento avisa que está com ganho.
                            color: comp.muted
                                   ? Qt.rgba(1,1,1,0.15)
                                   : (comp.value > 1.0 ? "#e5c890" : Theme.active)
                            Behavior on width { NumberAnimation { duration: 80 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.SizeHorCursor
                            function calc(mx) {
                                return Math.max(0.0, Math.min(comp.maxValue,
                                                (mx / width) * comp.maxValue))
                            }
                            onPressed: comp.volumeChanged(calc(mouseX))
                            onPositionChanged: if (pressed) comp.volumeChanged(calc(mouseX))
                        }

                        WheelHandler {
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: function(event) {
                                var step = 0.05
                                var delta = event.angleDelta.y > 0 ? step : -step
                                comp.volumeChanged(Math.max(0.0,
                                    Math.min(comp.maxValue, comp.value + delta)))
                            }
                        }
                    }
                }
            }

            Text {
                Layout.preferredWidth: 35
                text: comp.pctText
                color: comp.muted ? Qt.rgba(1,1,1,0.25)
                                  : (comp.value > 1.0 ? "#e5c890" : Theme.text)
                font.pixelSize: 11
                font.bold: true
                horizontalAlignment: Text.AlignRight
            }
        }

        // ── Lista de saídas do app (expande sob a linha) ─────────────────────
        Column {
            id: routeList
            visible: comp.routeOpen && comp.hasRouting
            anchors.top:        mainRow.bottom
            anchors.left:       parent.left
            anchors.right:      parent.right
            anchors.topMargin:  4
            anchors.leftMargin:  44   // alinha com o texto, depois do botão de mute
            anchors.rightMargin: 12
            spacing: 2

            Repeater {
                model: comp.routeTargets
                delegate: Rectangle {
                    id: sinkRow
                    required property var modelData
                    readonly property bool isCurrent:
                        root.deviceName(modelData) === comp.routeCurrent

                    width:  routeList.width
                    height: 22
                    radius: 4
                    color: sinkRow.isCurrent
                           ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
                           : (sinkHover.hovered ? Qt.rgba(1,1,1,0.08) : "transparent")

                    Text {
                        anchors.left:           parent.left
                        anchors.leftMargin:     8
                        anchors.verticalCenter: parent.verticalCenter
                        width:  parent.width - 16
                        text:   root.deviceName(sinkRow.modelData)
                        color:  sinkRow.isCurrent ? Theme.active : Qt.rgba(1,1,1,0.6)
                        font.pixelSize: 9
                        elide:  Text.ElideRight
                    }

                    HoverHandler { id: sinkHover; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            comp.routePicked(sinkRow.modelData)
                            comp.routeOpen = false
                        }
                    }
                }
            }
        }
    }

    // ── SectionLabel ──────────────────────────────────────────────────────────
    component SectionLabel: Text {
        color:           Qt.rgba(1, 1, 1, 0.35)
        font.pixelSize:  10
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.8
        leftPadding: 4
        topPadding:  2
    }
}
