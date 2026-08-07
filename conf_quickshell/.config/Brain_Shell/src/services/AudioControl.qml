import QtQuick
import QtQuick.Layouts
import Quickshell
import "../components"
import "../"

Item {
    id: root

    property string page: normalizePage(Popups.audioPage)
    property bool showTechnicalProfiles: false
    property string pendingProfile: ""

    readonly property var outputDevice: AudioService.selectedSink()
    readonly property var inputDevice: AudioService.selectedSource()
    readonly property int cardRadius: Math.max(9, Theme.cornerRadius)

    function normalizePage(value) {
        if (value === "mixer") return "apps"
        if (value === "config") return "advanced"
        if (value === "input" || value === "output") return "general"
        return value === "apps" || value === "advanced" ? value : "general"
    }

    function setPage(value) {
        page = value
        Popups.audioPage = value
        pendingProfile = ""
    }

    function reset() {
        showTechnicalProfiles = false
        pendingProfile = ""
        outputCard.selectorOpen = false
        inputCard.selectorOpen = false
    }

    function sinkLabel(name) {
        for (const sink of AudioService.sinks)
            if (sink.name === name) return sink.label
        return ""
    }

    function profileToken(card, profile) {
        return String(card?.name ?? "") + "::" + String(profile?.key ?? "")
    }

    function selectProfile(card, profile) {
        const dangerous = profile.kind === "pro" || profile.kind === "off"
        const token = profileToken(card, profile)
        if (dangerous && pendingProfile !== token) {
            pendingProfile = token
            AudioService.notice = profile.kind === "pro"
                    ? "Click again to confirm Pro Audio mode"
                    : "Click again to confirm that you want to disable this card"
            AudioService.noticeIsError = true
            return
        }
        pendingProfile = ""
        AudioService.chooseProfile(card, profile)
    }

    Connections {
        target: Popups
        function onAudioPageChanged() { root.page = root.normalizePage(Popups.audioPage) }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 9

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: 12
                color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.14)

                Text {
                    anchors.centerIn: parent
                    text: "󰕾"
                    color: Theme.active
                    font.pixelSize: 19
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: "Audio"
                    color: Theme.text
                    font.pixelSize: 16
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    text: {
                        if (AudioService.loading && !AudioService.state.ok) return "Reading devices…"
                        const output = root.outputDevice?.label ?? "no output"
                        const input = root.inputDevice?.label ?? "no microphone"
                        return output + "  •  " + input
                    }
                    color: Qt.rgba(1, 1, 1, 0.40)
                    font.pixelSize: 9
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                Layout.preferredWidth: 31
                Layout.preferredHeight: 31
                radius: 9
                color: refreshHover.hovered ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.045)

                Text {
                    anchors.centerIn: parent
                    text: "󰑐"
                    color: AudioService.loading ? Theme.active : Qt.rgba(1, 1, 1, 0.55)
                    font.pixelSize: 13
                    rotation: AudioService.loading ? 180 : 0
                    Behavior on rotation { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                }

                HoverHandler { id: refreshHover; cursorShape: Qt.PointingHandCursor }
                MouseArea {
                    anchors.fill: parent
                    enabled: !AudioService.busy
                    onClicked: AudioService.refresh()
                }
            }
        }

        Rectangle {
            visible: AudioService.notice !== ""
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 31 : 0
            radius: 8
            color: AudioService.noticeIsError
                   ? Qt.rgba(0.96, 0.55, 0.24, 0.13)
                   : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.13)
            border.color: AudioService.noticeIsError
                          ? Qt.rgba(0.96, 0.55, 0.24, 0.28)
                          : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.28)

            Row {
                anchors.centerIn: parent
                spacing: 7

                Text {
                    text: AudioService.busy ? "󰔟" : (AudioService.noticeIsError ? "󰀦" : "󰄬")
                    color: AudioService.noticeIsError ? "#f5a45d" : Theme.active
                    font.pixelSize: 11
                }
                Text {
                    text: AudioService.notice
                    color: Theme.text
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, root.width - 55)
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 35
            radius: 10
            color: Qt.rgba(1, 1, 1, 0.045)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 3
                spacing: 3

                Repeater {
                    model: [
                        { key: "general", icon: "󰋋", label: "General" },
                        { key: "apps", icon: "󰏖", label: "Applications" },
                        { key: "advanced", icon: "󰒓", label: "Advanced" }
                    ]

                    delegate: Rectangle {
                        id: tab
                        required property var modelData
                        readonly property bool selected: root.page === modelData.key

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        color: selected
                               ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
                               : (tabHover.hovered ? Qt.rgba(1, 1, 1, 0.055) : "transparent")

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: tab.modelData.icon
                                color: tab.selected ? Theme.active : Qt.rgba(1, 1, 1, 0.48)
                                font.pixelSize: 11
                            }
                            Text {
                                text: tab.modelData.label
                                color: tab.selected ? Theme.text : Qt.rgba(1, 1, 1, 0.48)
                                font.pixelSize: 10
                                font.bold: tab.selected
                            }
                        }

                        HoverHandler { id: tabHover; cursorShape: Qt.PointingHandCursor }
                        MouseArea { anchors.fill: parent; onClicked: root.setPage(tab.modelData.key) }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Flickable {
                anchors.fill: parent
                visible: root.page === "general"
                contentHeight: generalColumn.implicitHeight + 3
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: generalColumn
                    width: parent.width
                    spacing: 9

                    Rectangle {
                        visible: AudioService.orphanCount > 0 || AudioService.effects.invalidDefault === true
                        width: parent.width
                        height: visible ? warningContent.implicitHeight + 20 : 0
                        radius: root.cardRadius
                        color: Qt.rgba(0.96, 0.55, 0.24, 0.11)
                        border.color: Qt.rgba(0.96, 0.55, 0.24, 0.28)
                        border.width: 1

                        RowLayout {
                            id: warningContent
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                margins: 10
                            }
                            spacing: 9

                            Text {
                                text: "󰀦"
                                color: "#f5a45d"
                                font.pixelSize: 17
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    text: AudioService.orphanCount > 0
                                          ? "Application route was interrupted"
                                          : "EasyEffects became the default output"
                                    color: Theme.text
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: AudioService.orphanCount > 0
                                          ? "Try reconnecting. If the app kept the old route, pause and resume its audio."
                                          : "The physical device should remain the default."
                                    color: Qt.rgba(1, 1, 1, 0.43)
                                    font.pixelSize: 9
                                    wrapMode: Text.Wrap
                                }
                            }

                            ActionButton {
                                label: "Reconnect"
                                accent: true
                                onClicked: AudioService.repair()
                            }
                        }
                    }

                    AudioEndpointCard {
                        id: outputCard
                        width: parent.width
                        heading: "Listen through"
                        input: false
                        endpoint: root.outputDevice
                        endpoints: AudioService.sinks
                        audioNode: AudioService.outputNode
                        signalLevel: AudioService.outputPeak
                        onDevicePicked: function(device) { AudioService.chooseOutput(device) }
                        onPortPicked: function(device, port) { AudioService.chooseOutputPort(device, port) }
                    }

                    AudioEndpointCard {
                        id: inputCard
                        width: parent.width
                        heading: "Speak through"
                        input: true
                        endpoint: root.inputDevice
                        endpoints: AudioService.sources
                        audioNode: AudioService.inputNode
                        signalLevel: AudioService.inputPeak
                        onDevicePicked: function(device) { AudioService.chooseInput(device) }
                        onPortPicked: function(device, port) { AudioService.chooseInputPort(device, port) }
                    }

                    Rectangle {
                        width: parent.width
                        height: 82
                        radius: root.cardRadius
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.color: AudioService.effects.enabled
                                      ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.30)
                                      : Qt.rgba(1, 1, 1, 0.07)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 11
                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 36
                                radius: 11
                                color: AudioService.effects.enabled
                                       ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.15)
                                       : Qt.rgba(1, 1, 1, 0.055)

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰓃"
                                    color: AudioService.effects.enabled ? Theme.active : Qt.rgba(1, 1, 1, 0.45)
                                    font.pixelSize: 16
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: "EasyEffects • output"
                                    color: Theme.text
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: !AudioService.effects.installed
                                          ? "Not installed"
                                          : (!AudioService.effects.running
                                             ? "Stopped • turn it on to start"
                                          : (AudioService.effects.enabled
                                             ? "On • preset " + (AudioService.effects.preset || "current")
                                             : "Bypass • effects skipped, physical output preserved"))
                                    color: Qt.rgba(1, 1, 1, 0.40)
                                    font.pixelSize: 9
                                    elide: Text.ElideRight
                                }
                            }

                            ActionButton {
                                label: "Open"
                                onClicked: Quickshell.execDetached(["easyeffects"])
                            }

                            Rectangle {
                                Layout.preferredWidth: 38
                                Layout.preferredHeight: 21
                                radius: height / 2
                                color: AudioService.effects.enabled
                                       ? Theme.active
                                       : Qt.rgba(1, 1, 1, 0.13)

                                Rectangle {
                                    width: 15
                                    height: 15
                                    radius: 8
                                    y: 3
                                    x: AudioService.effects.enabled ? parent.width - width - 3 : 3
                                    color: AudioService.effects.enabled ? "#ffffff" : Qt.rgba(1, 1, 1, 0.65)
                                    Behavior on x { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: AudioService.effects.available && !AudioService.busy
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: AudioService.setEffects(!AudioService.effects.enabled)
                                }
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        text: "Output and microphone are independent: connecting a microphone does not change where sound plays."
                        color: Qt.rgba(1, 1, 1, 0.30)
                        font.pixelSize: 9
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                        topPadding: 2
                    }
                }
            }

            Flickable {
                anchors.fill: parent
                visible: root.page === "apps"
                contentHeight: appsColumn.implicitHeight + 3
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: appsColumn
                    width: parent.width
                    spacing: 7

                    SectionTitle { width: parent.width; title: "Playback"; subtitle: "Volume and output per application" }

                    Text {
                        visible: AudioService.effects.running
                        width: parent.width
                        text: "EasyEffects combines playback into one route. Turn it off in General to choose a different output per application."
                        color: "#f5a45d"
                        font.pixelSize: 9
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                        bottomPadding: 2
                    }

                    Repeater {
                        model: AudioService.playbackStreams
                        delegate: AudioAppRow {
                            required property var modelData
                            width: appsColumn.width
                            streamNode: modelData
                            recording: false
                            routeTargets: AudioService.effects.running ? [] : AudioService.sinks
                            routeCurrent: {
                                const route = AudioService.streamRoute(modelData)
                                return route ? route.sinkName : ""
                            }
                            routeLabel: root.sinkLabel(routeCurrent)
                            onRoutePicked: function(sink) { AudioService.moveStream(modelData, sink) }
                        }
                    }

                    EmptyState {
                        width: parent.width
                        visible: AudioService.playbackStreams.length === 0
                        message: "No applications are playing audio"
                    }

                    Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.07) }

                    SectionTitle { width: parent.width; title: "Recording"; subtitle: "Microphone and system audio capture" }

                    Repeater {
                        model: AudioService.recordingStreams
                        delegate: AudioAppRow {
                            required property var modelData
                            width: appsColumn.width
                            streamNode: modelData
                            recording: true
                            systemCapture: AudioService.recordingRoute(modelData)?.isMonitor === true
                        }
                    }

                    EmptyState {
                        width: parent.width
                        visible: AudioService.recordingStreams.length === 0
                        message: "No applications are recording audio"
                    }
                }
            }

            Flickable {
                anchors.fill: parent
                visible: root.page === "advanced"
                contentHeight: advancedColumn.implicitHeight + 3
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: advancedColumn
                    width: parent.width
                    spacing: 9

                    Rectangle {
                        width: parent.width
                        height: 72
                        radius: root.cardRadius
                        color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.08)
                        border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.20)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 11
                            spacing: 10
                            Text { text: "󰑓"; color: Theme.active; font.pixelSize: 19 }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text { text: "Restore routes"; color: Theme.text; font.pixelSize: 11; font.bold: true }
                                Text {
                                    Layout.fillWidth: true
                                    text: "Returns to Sound + microphone mode and restores physical devices."
                                    color: Qt.rgba(1, 1, 1, 0.40)
                                    font.pixelSize: 9
                                    wrapMode: Text.Wrap
                                }
                            }
                            ActionButton { label: "Restore"; accent: true; onClicked: AudioService.repair() }
                        }
                    }

                    SectionTitle {
                        width: parent.width
                        title: "Card mode"
                        subtitle: "Duplex is the normal choice for sound + microphone"
                    }

                    Repeater {
                        model: AudioService.cards

                        delegate: Rectangle {
                            id: cardBox
                            required property var modelData
                            readonly property var cardData: modelData

                            width: advancedColumn.width
                            height: cardColumn.implicitHeight + 22
                            radius: root.cardRadius
                            color: Qt.rgba(1, 1, 1, 0.038)
                            border.color: Qt.rgba(1, 1, 1, 0.065)
                            border.width: 1

                            Column {
                                id: cardColumn
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                    margins: 11
                                }
                                spacing: 5

                                Text {
                                    width: parent.width
                                    text: cardBox.cardData.label
                                    color: Theme.text
                                    font.pixelSize: 11
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Repeater {
                                    model: AudioService.profilesFor(cardBox.cardData, root.showTechnicalProfiles)

                                    delegate: Rectangle {
                                        id: profileRow
                                        required property var modelData
                                        readonly property var profileData: modelData
                                        readonly property bool dangerous: profileData.kind === "pro" || profileData.kind === "off"
                                        readonly property string token: root.profileToken(cardBox.cardData, profileData)
                                        readonly property bool confirming: root.pendingProfile === token

                                        width: cardColumn.width
                                        height: 52
                                        radius: 8
                                        color: profileData.active
                                               ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.13)
                                               : (profileHover.hovered ? Qt.rgba(1, 1, 1, 0.055) : "transparent")
                                        border.color: confirming ? "#f5a45d" : "transparent"
                                        border.width: confirming ? 1 : 0

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 9

                                            Rectangle {
                                                Layout.preferredWidth: 28
                                                Layout.preferredHeight: 28
                                                radius: 9
                                                color: profileRow.profileData.active
                                                       ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
                                                       : (profileRow.dangerous ? Qt.rgba(0.96, 0.55, 0.24, 0.12)
                                                                               : Qt.rgba(1, 1, 1, 0.05))
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: profileRow.profileData.kind === "duplex" ? "󰂚"
                                                          : profileRow.profileData.kind === "output" ? "󰕾"
                                                          : profileRow.profileData.kind === "input" ? "󰍬"
                                                          : profileRow.profileData.kind === "pro" ? "󰐹" : "󰅖"
                                                    color: profileRow.profileData.active ? Theme.active
                                                           : (profileRow.dangerous ? "#f5a45d" : Qt.rgba(1, 1, 1, 0.48))
                                                    font.pixelSize: 13
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1
                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 5
                                                    Text {
                                                        text: profileRow.profileData.title
                                                        color: Theme.text
                                                        font.pixelSize: 10
                                                        font.bold: true
                                                    }
                                                    Text {
                                                        visible: profileRow.profileData.recommended
                                                        text: "RECOMMENDED"
                                                        color: Theme.active
                                                        font.pixelSize: 7
                                                        font.bold: true
                                                    }
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: AudioService.profileHint(profileRow.profileData)
                                                    color: Qt.rgba(1, 1, 1, 0.36)
                                                    font.pixelSize: 8
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            Text {
                                                visible: profileRow.profileData.active || profileRow.confirming
                                                text: profileRow.confirming ? "Confirm" : "󰄬"
                                                color: profileRow.confirming ? "#f5a45d" : Theme.active
                                                font.pixelSize: profileRow.confirming ? 9 : 12
                                                font.bold: true
                                            }
                                        }

                                        HoverHandler { id: profileHover; cursorShape: Qt.PointingHandCursor }
                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: !AudioService.busy && !profileRow.profileData.active
                                            onClicked: root.selectProfile(cardBox.cardData, profileRow.profileData)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 36
                        radius: 9
                        color: technicalHover.hovered ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.035)

                        Row {
                            anchors.centerIn: parent
                            spacing: 7
                            Text {
                                text: root.showTechnicalProfiles ? "󰅀" : "󰅂"
                                color: Qt.rgba(1, 1, 1, 0.45)
                                font.pixelSize: 11
                            }
                            Text {
                                text: root.showTechnicalProfiles ? "Hide Pro Audio and Disabled" : "Show technical modes"
                                color: Qt.rgba(1, 1, 1, 0.55)
                                font.pixelSize: 9
                            }
                        }

                        HoverHandler { id: technicalHover; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.showTechnicalProfiles = !root.showTechnicalProfiles
                                root.pendingProfile = ""
                            }
                        }
                    }

                    SectionTitle { width: parent.width; title: "Diagnostics"; subtitle: "Full controls when you need them" }

                    Rectangle {
                        width: parent.width
                        height: diagnosticColumn.implicitHeight + 22
                        radius: root.cardRadius
                        color: Qt.rgba(1, 1, 1, 0.038)
                        border.color: Qt.rgba(1, 1, 1, 0.065)

                        Column {
                            id: diagnosticColumn
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: 11
                            }
                            spacing: 7

                            DiagnosticRow { width: parent.width; label: "Default output"; value: root.outputDevice?.label ?? "None" }
                            DiagnosticRow { width: parent.width; label: "Default microphone"; value: root.inputDevice?.label ?? "None" }
                            DiagnosticRow {
                                width: parent.width
                                label: "EasyEffects"
                                value: AudioService.effects.enabled
                                       ? "On (" + (AudioService.effects.preset || "current preset") + ")"
                                       : "Off"
                            }
                            DiagnosticRow {
                                width: parent.width
                                label: "Lost routes"
                                value: String(AudioService.orphanCount)
                                warning: AudioService.orphanCount > 0
                            }

                            RowLayout {
                                width: parent.width
                                spacing: 7
                                ActionButton {
                                    Layout.fillWidth: true
                                    label: "Pavucontrol"
                                    onClicked: Quickshell.execDetached(["pavucontrol"])
                                }
                                ActionButton {
                                    Layout.fillWidth: true
                                    label: "EasyEffects"
                                    onClicked: Quickshell.execDetached(["easyeffects"])
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: AudioService.busy
        z: 100
        color: Qt.rgba(0, 0, 0, 0.12)
        MouseArea { anchors.fill: parent }
    }

    component ActionButton: Rectangle {
        id: button
        property string label: ""
        property bool accent: false
        signal clicked()

        implicitWidth: buttonText.implicitWidth + 18
        implicitHeight: 27
        radius: 8
        color: accent
               ? (buttonHover.hovered ? Theme.active : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.72))
               : (buttonHover.hovered ? Qt.rgba(1, 1, 1, 0.11) : Qt.rgba(1, 1, 1, 0.06))

        Text {
            id: buttonText
            anchors.centerIn: parent
            text: button.label
            color: button.accent ? "#ffffff" : Theme.text
            font.pixelSize: 9
            font.bold: true
        }

        HoverHandler { id: buttonHover; cursorShape: Qt.PointingHandCursor }
        MouseArea {
            anchors.fill: parent
            enabled: !AudioService.busy
            onClicked: button.clicked()
        }
    }

    component SectionTitle: Item {
        property string title: ""
        property string subtitle: ""
        implicitHeight: titleColumn.implicitHeight + 3

        Column {
            id: titleColumn
            width: parent.width
            spacing: 1
            Text {
                text: parent.parent.title
                color: Theme.text
                font.pixelSize: 11
                font.bold: true
            }
            Text {
                width: parent.width
                text: parent.parent.subtitle
                color: Qt.rgba(1, 1, 1, 0.35)
                font.pixelSize: 8
                elide: Text.ElideRight
            }
        }
    }

    component EmptyState: Rectangle {
        property string message: ""
        height: visible ? 48 : 0
        radius: 9
        color: Qt.rgba(1, 1, 1, 0.025)
        Text {
            anchors.centerIn: parent
            text: parent.message
            color: Qt.rgba(1, 1, 1, 0.28)
            font.pixelSize: 9
        }
    }

    component DiagnosticRow: RowLayout {
        property string label: ""
        property string value: ""
        property bool warning: false
        spacing: 8
        Text {
            text: parent.label
            color: Qt.rgba(1, 1, 1, 0.38)
            font.pixelSize: 9
        }
        Item { Layout.fillWidth: true }
        Text {
            Layout.maximumWidth: 245
            text: parent.value
            color: parent.warning ? "#f5a45d" : Theme.text
            font.pixelSize: 9
            font.bold: true
            elide: Text.ElideLeft
            horizontalAlignment: Text.AlignRight
        }
    }
}
