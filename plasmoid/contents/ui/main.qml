import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property string customAppIcon: Qt.resolvedUrl("../icons/plasma-bonsai.svg")
    Plasmoid.icon: root.customAppIcon
    Plasmoid.title: "Plasma Bonsai Assistant"

    // Configuración directa a Ollama (sin demonio)
    property string ollamaUrl: (Plasmoid.configuration && Plasmoid.configuration.ollamaUrl) ? Plasmoid.configuration.ollamaUrl : "http://127.0.0.1:11434"
    property string preferredLanguage: (Plasmoid.configuration && Plasmoid.configuration.preferredLanguage) ? Plasmoid.configuration.preferredLanguage : "auto"
    property string customSystemPrompt: (Plasmoid.configuration && Plasmoid.configuration.customSystemPrompt) ? Plasmoid.configuration.customSystemPrompt : ""
    property bool showSettings: false
    property bool ollamaConnected: false
    property bool isBusy: false
    property bool isRecordingVoice: false
    property string capturedImageB64: ""
    property var availableModels: []
    property string currentModel: ""
    property var toolDefinitions: []
    property var conversationHistory: []

    Timer {
        id: startOllamaRetryTimer
        interval: 1500
        repeat: false
        onTriggered: root.checkOllamaHealth()
    }

    // Gestor de llamadas asíncronas a CLI / herramientas
    property var commandCallbacks: ({})
    property int cmdCounter: 0

    readonly property string toolsScriptPath: {
        var url = Qt.resolvedUrl("../code/tools.py").toString()
        return url.replace(/^file:\/\//, "")
    }

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            if (root.commandCallbacks[sourceName]) {
                var cb = root.commandCallbacks[sourceName]
                delete root.commandCallbacks[sourceName]
                cb(data["exit code"], data["stdout"] || "", data["stderr"] || "")
            }
            disconnectSource(sourceName)
        }
    }

    function runCli(cmd, callback) {
        root.cmdCounter++
        var uniqueCmd = cmd + " # " + root.cmdCounter
        if (callback) {
            root.commandCallbacks[uniqueCmd] = callback
        }
        executable.connectSource(uniqueCmd)
    }

    ListModel {
        id: chatModel
    }

    ListModel {
        id: modelComboModel
    }

    // Representación compacta (icono para panel)
    compactRepresentation: MouseArea {
        id: compactArea
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) - Kirigami.Units.smallSpacing
            height: width
            source: root.Plasmoid.icon
            active: compactArea.containsMouse
        }
    }

    // Representación completa (ventana emergente o widget de escritorio)
    fullRepresentation: Item {
        id: fullRepItem
        Layout.minimumWidth: Kirigami.Units.gridUnit * 22
        Layout.minimumHeight: Kirigami.Units.gridUnit * 26
        Layout.preferredWidth: Kirigami.Units.gridUnit * 26
        Layout.preferredHeight: Kirigami.Units.gridUnit * 30

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            // Cabecera
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: root.customAppIcon
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                }

                PlasmaComponents.Label {
                    text: "Bonsai"
                    font.bold: true
                }

                // Selector de modelo Ollama
                PlasmaComponents.ComboBox {
                    id: modelCombo
                    visible: root.ollamaConnected && modelComboModel.count > 0
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 9
                    Layout.fillWidth: true
                    model: modelComboModel
                    textRole: "text"
                    currentIndex: {
                        for (var i = 0; i < modelComboModel.count; i++) {
                            if (modelComboModel.get(i).text === root.currentModel) return i;
                        }
                        return 0;
                    }
                    onActivated: {
                        root.currentModel = modelComboModel.get(index).text
                    }
                }

                // Indicador de estado de conexión con Ollama
                Rectangle {
                    width: Kirigami.Units.gridUnit * 0.5
                    height: width
                    radius: width / 2
                    color: root.ollamaConnected ? "#27ae60" : "#e74c3c"
                    Layout.alignment: Qt.AlignVCenter
                    ToolTip.text: root.ollamaConnected ? i18n("Connected to Ollama (127.0.0.1:11434)") : i18n("Ollama not reachable")
                    ToolTip.visible: statusMouse.containsMouse

                    MouseArea {
                        id: statusMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.checkOllamaHealth()
                    }
                }

                PlasmaComponents.ToolButton {
                    icon.name: "edit-clear-all"
                    text: i18n("Clear")
                    display: PlasmaComponents.AbstractButton.IconOnly
                    ToolTip.text: i18n("Clear conversation")
                    ToolTip.visible: hovered
                    onClicked: root.clearChat()
                }

                PlasmaComponents.ToolButton {
                    icon.name: root.showSettings ? "chat" : "configure"
                    text: root.showSettings ? i18n("Chat") : i18n("Configure")
                    display: PlasmaComponents.AbstractButton.IconOnly
                    ToolTip.text: root.showSettings ? i18n("Back to chat") : i18n("Configure Bonsai")
                    ToolTip.visible: hovered
                    onClicked: root.showSettings = !root.showSettings
                }
            }

            // ==========================================
            // Vista Principal del Chat
            // ==========================================
            ColumnLayout {
                id: chatViewLayout
                visible: !root.showSettings
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Kirigami.Units.smallSpacing

                // Banner informativo si Ollama está detenido o sin modelos
                Rectangle {
                visible: !root.ollamaConnected || (root.ollamaConnected && root.availableModels.length === 0)
                Layout.fillWidth: true
                implicitHeight: warningRow.implicitHeight + 14
                radius: 4
                color: !root.ollamaConnected ? "#c0392b" : "#d35400"

                RowLayout {
                    id: warningRow
                    anchors.fill: parent
                    anchors.margins: 7
                    spacing: Kirigami.Units.smallSpacing

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            font.bold: true
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            color: "#ffffff"
                            text: !root.ollamaConnected 
                                  ? i18n("⚠️ Ollama is not running on localhost:11434")
                                  : i18n("⚠️ No models downloaded in Ollama")
                        }

                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                            color: "#ffffff"
                            wrapMode: Text.Wrap
                            text: !root.ollamaConnected 
                                  ? i18n("Click the button to start Ollama or run 'ollama serve'.")
                                  : i18n("Download a model: 'ollama pull bonsai-2' or 'ollama pull qwen2.5'")
                        }
                    }

                    PlasmaComponents.Button {
                        visible: !root.ollamaConnected
                        icon.name: "media-playback-start"
                        text: i18n("Start")
                        onClicked: root.startOllamaService()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Kirigami.Theme.disabledTextColor
                opacity: 0.25
            }

            // Lista de mensajes del chat
            ListView {
                id: chatListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Kirigami.Units.smallSpacing
                model: chatModel

                ScrollBar.vertical: ScrollBar {
                    active: true
                }

                onCountChanged: {
                    Qt.callLater(function() {
                        chatListView.positionViewAtEnd()
                    })
                }

                delegate: Item {
                    id: bubbleDelegate
                    width: chatListView.width
                    height: isWelcome ? (welcomeCard.height + 12) : (bubbleBox.visible ? (bubbleBox.height + 10) : 0)

                    readonly property bool isWelcome: model.role === "welcome"
                    readonly property bool isUser: model.role === "user"

                    // Tarjeta de bienvenida inicial
                    Rectangle {
                        id: welcomeCard
                        visible: bubbleDelegate.isWelcome
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 4
                        width: Math.min(bubbleDelegate.width - 24, 460)
                        height: welcomeCol.implicitHeight + 18
                        radius: 8
                        color: Kirigami.Theme.backgroundColor
                        border.color: "#27ae60"
                        border.width: 1

                        ColumnLayout {
                            id: welcomeCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 10
                            spacing: 6

                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 8

                                Kirigami.Icon {
                                    source: root.customAppIcon
                                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                }

                                PlasmaComponents.Label {
                                    text: "Plasma Bonsai Assistant"
                                    font.bold: true
                                    color: "#27ae60"
                                }
                            }

                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: model.text
                                wrapMode: Text.Wrap
                                horizontalAlignment: Text.AlignHCenter
                                textFormat: Text.MarkdownText
                                opacity: 0.9
                                color: Kirigami.Theme.textColor
                            }
                        }
                    }

                    // Burbujas de mensajes normales
                    Rectangle {
                        id: bubbleBox
                        visible: !bubbleDelegate.isWelcome && (model.text !== "" || (model.toolInfo && model.toolInfo !== ""))
                        anchors.top: parent.top
                        anchors.topMargin: 4
                        anchors.left: bubbleDelegate.isUser ? undefined : parent.left
                        anchors.right: bubbleDelegate.isUser ? parent.right : undefined
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8

                        width: Math.min(bubbleDelegate.width * 0.90, 520)
                        height: innerCol.implicitHeight + 18
                        radius: 8
                        color: bubbleDelegate.isUser 
                               ? Kirigami.Theme.highlightColor 
                               : Kirigami.Theme.backgroundColor
                        border.color: Kirigami.Theme.disabledTextColor
                        border.width: 1

                        Column {
                            id: innerCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 9
                            spacing: 5

                            RowLayout {
                                width: parent.width

                                PlasmaComponents.Label {
                                    text: bubbleDelegate.isUser ? i18n("You") : "Bonsai"
                                    font.bold: true
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    color: bubbleDelegate.isUser ? Kirigami.Theme.highlightedTextColor : "#27ae60"
                                }

                                Item { Layout.fillWidth: true }

                                // Botón para escuchar respuesta (TTS)
                                PlasmaComponents.ToolButton {
                                    visible: !bubbleDelegate.isUser && model.text !== ""
                                    icon.name: "audio-volume-high"
                                    display: PlasmaComponents.AbstractButton.IconOnly
                                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                    ToolTip.text: i18n("Listen to response")
                                    ToolTip.visible: hovered
                                    onClicked: root.speakResponse(model.text)
                                }

                                // Botón para copiar respuesta
                                PlasmaComponents.ToolButton {
                                    visible: !bubbleDelegate.isUser && model.text !== ""
                                    icon.name: "edit-copy"
                                    display: PlasmaComponents.AbstractButton.IconOnly
                                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                    ToolTip.text: i18n("Copy response to clipboard")
                                    ToolTip.visible: hovered
                                    onClicked: root.copyToClipboard(model.text)
                                }
                            }

                            // Mensaje con soporte para Markdown enriquecido
                            PlasmaComponents.Label {
                                id: msgLabel
                                width: parent.width
                                text: model.text
                                wrapMode: Text.Wrap
                                textFormat: Text.MarkdownText
                                color: bubbleDelegate.isUser 
                                       ? Kirigami.Theme.highlightedTextColor 
                                       : Kirigami.Theme.textColor
                                onLinkActivated: (link) => Qt.openUrlExternally(link)
                            }

                            // Indicador de herramienta ejecutada
                            Rectangle {
                                visible: model.toolInfo && model.toolInfo !== ""
                                width: Math.min(toolLabel.implicitWidth + 14, parent.width)
                                height: toolLabel.implicitHeight + 6
                                radius: 4
                                color: Kirigami.Theme.backgroundColor
                                border.color: "#27ae60"
                                border.width: 1

                                PlasmaComponents.Label {
                                    id: toolLabel
                                    anchors.centerIn: parent
                                    width: parent.width - 10
                                    elide: Text.ElideRight
                                    text: "🔧 " + (model.toolInfo || "")
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                                    color: Kirigami.Theme.textColor
                                }
                            }
                        }
                    }
                }
            }

            // Vista previa de captura adjunta
            RowLayout {
                visible: root.capturedImageB64 !== ""
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Rectangle {
                    color: Kirigami.Theme.highlightColor
                    radius: 3
                    implicitWidth: imgBadge.implicitWidth + 8
                    implicitHeight: imgBadge.implicitHeight + 4

                    PlasmaComponents.Label {
                        id: imgBadge
                        anchors.centerIn: parent
                        text: "📸 " + i18n("Screenshot ready for analysis")
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        color: Kirigami.Theme.highlightedTextColor
                    }
                }

                PlasmaComponents.ToolButton {
                    icon.name: "dialog-close"
                    display: PlasmaComponents.AbstractButton.IconOnly
                    onClicked: root.capturedImageB64 = ""
                }
            }

            // Indicador de inferencia en curso
            RowLayout {
                visible: root.isBusy
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.BusyIndicator {
                    running: root.isBusy
                    Layout.preferredWidth: Kirigami.Units.gridUnit
                    Layout.preferredHeight: Kirigami.Units.gridUnit
                }

                PlasmaComponents.Label {
                    text: root.getThinkingText()
                    font.italic: true
                    opacity: 0.75
                }
            }

            // Barra inferior de entrada
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.ToolButton {
                    id: micBtn
                    icon.name: root.isRecordingVoice ? "media-record" : "audio-input-microphone"
                    display: PlasmaComponents.AbstractButton.IconOnly
                    ToolTip.text: root.isRecordingVoice ? i18n("Stop recording and send") : i18n("Voice input (Push-to-talk)")
                    ToolTip.visible: hovered
                    enabled: !root.isBusy
                    onClicked: root.toggleVoiceInput()
                }

                PlasmaComponents.ToolButton {
                    icon.name: "camera-photo"
                    ToolTip.text: i18n("Capture screenshot to analyze")
                    ToolTip.visible: hovered
                    enabled: !root.isBusy && !root.isRecordingVoice
                    onClicked: root.requestScreenshot()
                }

                PlasmaComponents.TextField {
                    id: promptInput
                    Layout.fillWidth: true
                    placeholderText: root.getPlaceholderText()
                    enabled: !root.isBusy && !root.isRecordingVoice
                    onAccepted: {
                        var val = promptInput.text.trim()
                        if (val !== "" || root.capturedImageB64 !== "") {
                            root.sendMessage(val)
                            promptInput.text = ""
                        }
                    }
                }

                PlasmaComponents.Button {
                    id: sendBtn
                    icon.name: "document-send"
                    text: i18n("Send")
                    enabled: !root.isBusy && (promptInput.text.length > 0 || root.capturedImageB64 !== "")
                    onClicked: {
                        var val = promptInput.text.trim()
                        if (val !== "" || root.capturedImageB64 !== "") {
                            root.sendMessage(val)
                            promptInput.text = ""
                        }
                    }
                }
            }
        } // Fin de chatViewLayout

        // ==========================================
        // Vista de Configuración Integrada
        // ==========================================
        ColumnLayout {
            id: settingsViewLayout
            visible: root.showSettings
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Kirigami.Units.largeSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Label {
                    text: i18n("⚙️ Bonsai Settings")
                    font.bold: true
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.15
                    Layout.fillWidth: true
                }

                PlasmaComponents.Button {
                    icon.name: "go-previous"
                    text: i18n("Back")
                    onClicked: root.showSettings = false
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Kirigami.Theme.disabledTextColor
                opacity: 0.25
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    width: parent.width
                    spacing: Kirigami.Units.mediumSpacing

                    // 1. Ollama URL
                    PlasmaComponents.Label {
                        text: i18n("Ollama Server URL:")
                        font.bold: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents.TextField {
                            id: settingsUrlInput
                            Layout.fillWidth: true
                            text: root.ollamaUrl
                            placeholderText: "http://127.0.0.1:11434"
                        }

                        PlasmaComponents.Button {
                            text: i18n("Test")
                            icon.name: "network-connect"
                            onClicked: {
                                root.ollamaUrl = settingsUrlInput.text.trim() || "http://127.0.0.1:11434"
                                root.checkOllamaHealth()
                            }
                        }
                    }

                    // 2. Idioma de Respuesta
                    PlasmaComponents.Label {
                        text: i18n("Response Language:")
                        font.bold: true
                    }

                    PlasmaComponents.ComboBox {
                        id: settingsLangCombo
                        Layout.fillWidth: true
                        textRole: "text"
                        model: [
                            { text: i18n("Automatic (match user input)"), value: "auto" },
                            { text: i18n("Always English"), value: "en" },
                            { text: i18n("Always Spanish"), value: "es" }
                        ]
                        Component.onCompleted: {
                            for (var i = 0; i < model.length; i++) {
                                if (model[i].value === root.preferredLanguage) {
                                    currentIndex = i
                                    break
                                }
                            }
                        }
                    }

                    // 3. System Prompt Personalizado
                    PlasmaComponents.Label {
                        text: i18n("Custom Instructions (System Prompt):")
                        font.bold: true
                    }

                    PlasmaComponents.TextArea {
                        id: settingsCustomPromptInput
                        Layout.fillWidth: true
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 5
                        text: root.customSystemPrompt
                        placeholderText: i18n("Optional instructions (e.g. 'Always answer in English, be concise and use bullet points').")
                        wrapMode: TextEdit.Wrap
                    }

                    Item { Layout.fillHeight: true }

                    // 4. Botón Guardar
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents.Button {
                            icon.name: "dialog-ok-apply"
                            text: i18n("Save Settings")
                            Layout.fillWidth: true
                            onClicked: {
                                var newUrl = settingsUrlInput.text.trim() || "http://127.0.0.1:11434"
                                root.ollamaUrl = newUrl
                                var sel = settingsLangCombo.model[settingsLangCombo.currentIndex]
                                root.preferredLanguage = sel ? sel.value : "auto"
                                root.customSystemPrompt = settingsCustomPromptInput.text.trim()

                                if (Plasmoid.configuration) {
                                    Plasmoid.configuration.ollamaUrl = root.ollamaUrl
                                    Plasmoid.configuration.preferredLanguage = root.preferredLanguage
                                    Plasmoid.configuration.customSystemPrompt = root.customSystemPrompt
                                }

                                if (chatModel.count > 0 && chatModel.get(0).role === "welcome") {
                                    chatModel.setProperty(0, "text", root.getWelcomeMessage())
                                }

                                root.checkOllamaHealth()
                                root.fetchModels()
                                root.showSettings = false
                            }
                        }
                    }

                    // 5. Apoyar el proyecto / GitHub Sponsors
                    PlasmaComponents.ToolButton {
                        text: root.preferredLanguage === "en" ? "💖 Support on GitHub Sponsors" : i18n("💖 Apoyar en GitHub Sponsors")
                        icon.name: "help-donate"
                        Layout.fillWidth: true
                        onClicked: Qt.openUrlExternally("https://github.com/sponsors/Canx")
                    }
                }
            }
        }
    }
    }

    // Comprobación periódica de Ollama
    Timer {
        id: healthCheckTimer
        interval: 4000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.checkOllamaHealth()
    }

    function getWelcomeMessage() {
        if (root.preferredLanguage === "en") {
            return "Hello! I am Bonsai, your native local assistant for KDE Plasma. I can answer questions, analyze screenshots, or control desktop settings (brightness, volume, notifications, windows) completely offline via Ollama."
        } else if (root.preferredLanguage === "es") {
            return "¡Hola! Soy Bonsai, tu asistente local nativo para KDE Plasma. Puedo responder preguntas, analizar capturas de pantalla o controlar el escritorio (brillo, volumen, notificaciones, ventanas) completamente en local mediante Ollama."
        }
        return i18n("Hello! I am Bonsai, your native local assistant for KDE Plasma. I can answer questions, analyze screenshots, or control desktop settings (brightness, volume, notifications, windows) completely offline via Ollama.")
    }

    function getClearedMessage() {
        if (root.preferredLanguage === "en") {
            return "Conversation cleared. How can I help you?"
        } else if (root.preferredLanguage === "es") {
            return "Conversación reiniciada. ¿En qué te puedo ayudar?"
        }
        return i18n("Conversation cleared. How can I help you?")
    }

    function getPlaceholderText() {
        if (root.isRecordingVoice) {
            if (root.preferredLanguage === "en") return "🔴 Listening… Click mic again to send"
            if (root.preferredLanguage === "es") return "🔴 Escuchando… Pulsa el micrófono para enviar"
            return i18n("🔴 Listening… Click mic again to send")
        }
        if (root.preferredLanguage === "en") return "Ask or request an action from Bonsai…"
        if (root.preferredLanguage === "es") return "Pregunta o pide una acción a Bonsai…"
        return i18n("Ask or request an action from Bonsai…")
    }

    function getThinkingText() {
        if (root.preferredLanguage === "en") return "Bonsai is thinking…"
        if (root.preferredLanguage === "es") return "Bonsai está pensando…"
        return i18n("Bonsai is thinking…")
    }

    onPreferredLanguageChanged: {
        if (chatModel.count === 1 && chatModel.get(0).role === "welcome") {
            chatModel.setProperty(0, "text", root.getWelcomeMessage())
        }
        root.loadToolSchema()
    }

    Component.onCompleted: {
        chatModel.append({
            "role": "welcome",
            "text": root.getWelcomeMessage(),
            "toolInfo": ""
        })

        // Cargar esquema de herramientas del sistema
        root.loadToolSchema()
    }

    function copyToClipboard(text) {
        if (!text) return
        var safe = text.replace(/'/g, "'\\''")
        root.runCli("printf '%s' '" + safe + "' | wl-copy 2>/dev/null || printf '%s' '" + safe + "' | xclip -selection clipboard 2>/dev/null", null)
    }

    function startOllamaService() {
        root.runCli("python3 '" + root.toolsScriptPath + "' start_ollama", (code, stdout) => {
            startOllamaRetryTimer.start()
        })
    }

    function speakResponse(text) {
        if (!text) return
        var safe = text.replace(/'/g, "'\\''")
        root.runCli("python3 '" + root.toolsScriptPath + "' speak '" + safe + "'", null)
    }

    function toggleVoiceInput() {
        if (!root.isRecordingVoice) {
            // Iniciar captura de audio
            root.isRecordingVoice = true
            root.runCli("python3 '" + root.toolsScriptPath + "' record start", (code, stdout) => {
                try {
                    var res = JSON.parse(stdout.trim())
                    if (!res.success) {
                        root.isRecordingVoice = false
                    }
                } catch (e) {
                    root.isRecordingVoice = false
                }
            })
        } else {
            // Detener captura y transcribir con Whisper
            root.isRecordingVoice = false
            root.isBusy = true
            root.runCli("python3 '" + root.toolsScriptPath + "' record stop", (code, stdout) => {
                root.runCli("python3 '" + root.toolsScriptPath + "' transcribe", (code2, stdout2) => {
                    root.isBusy = false
                    try {
                        var res2 = JSON.parse(stdout2.trim())
                        if (res2.success && res2.text && res2.text.trim() !== "") {
                            var spokenText = res2.text.trim()
                            root.sendMessage(spokenText)
                        } else if (res2.not_installed) {
                            chatModel.append({
                                "role": "assistant",
                                "text": i18n("Whisper Speech-to-Text is not installed. You can install it with: ./scripts/install-voice.sh"),
                                "toolInfo": ""
                            })
                        }
                    } catch (e) {}
                })
            })
        }
    }

    function detectLanguage(text) {
        if (!text) return (Qt.locale().name.indexOf("es") === 0 ? "es" : "en")
        var lower = text.toLowerCase()
        var enWords = [" the ", " and ", " to ", " set ", " create ", " find ", " search ", " open ", " why ", " is ", " for ", " with ", " brightness ", " volume ", " folder ", " file ", " in ", " how ", " what ", " make ", " of "]
        var esWords = [" el ", " la ", " los ", " las ", " y ", " de ", " en ", " pon ", " ajusta ", " crea ", " busca ", " abre ", " brillo ", " volumen ", " carpeta ", " archivo ", " por ", " cómo ", " que ", " qué ", " para "]
        var padded = " " + lower + " "
        var enCount = 0
        var esCount = 0
        for (var i = 0; i < enWords.length; i++) {
            if (padded.indexOf(enWords[i]) !== -1) enCount++
        }
        for (var j = 0; j < esWords.length; j++) {
            if (padded.indexOf(esWords[j]) !== -1) esCount++
        }
        if (enCount > esCount) return "en"
        if (esCount > enCount) return "es"
        return (Qt.locale().name.indexOf("es") === 0) ? "es" : "en"
    }

    function loadToolSchema(lang) {
        var l = lang || ((root.preferredLanguage && root.preferredLanguage !== "auto") ? root.preferredLanguage : (Qt.locale().name.indexOf("es") === 0 ? "es" : "en"))
        root.runCli("python3 '" + root.toolsScriptPath + "' --lang " + l + " schema", (code, stdout) => {
            if (code === 0 && stdout.trim() !== "") {
                try {
                    root.toolDefinitions = JSON.parse(stdout.trim())
                } catch (e) {
                    console.warn("Could not parse tool schema: " + e)
                }
            }
        })
    }

    function checkOllamaHealth() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", root.ollamaUrl + "/api/tags")
        xhr.timeout = 3000
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                root.ollamaConnected = (xhr.status === 200)
                if (xhr.status === 200) {
                    try {
                        var d = JSON.parse(xhr.responseText)
                        var list = d.models || []
                        var names = []
                        for (var i = 0; i < list.length; i++) {
                            names.push(list[i].name)
                        }
                        root.availableModels = names

                        if (names.length > 0) {
                            if (modelComboModel.count !== names.length) {
                                modelComboModel.clear()
                                for (var j = 0; j < names.length; j++) {
                                    modelComboModel.append({"text": names[j]})
                                }
                            }
                            if (root.currentModel === "" || names.indexOf(root.currentModel) === -1) {
                                // Preferir modelos de la familia bonsai o qwen si existen
                                var preferred = names[0]
                                for (var k = 0; k < names.length; k++) {
                                    if (names[k].indexOf("bonsai") !== -1) {
                                        preferred = names[k]
                                        break
                                    }
                                }
                                root.currentModel = preferred
                            }
                        } else {
                            modelComboModel.clear()
                            root.currentModel = ""
                        }
                    } catch (e) {
                        console.error("Error parsing Ollama tags: " + e)
                    }
                }
            }
        }
        xhr.send()
    }

    function clearChat() {
        chatModel.clear()
        root.conversationHistory = []
        chatModel.append({
            "role": "welcome",
            "text": root.getClearedMessage(),
            "toolInfo": ""
        })
    }

    function requestScreenshot() {
        root.isBusy = true
        root.runCli("python3 '" + root.toolsScriptPath + "' screenshot", (code, stdout) => {
            root.isBusy = false
            var b64 = (stdout || "").trim()
            if (b64.length > 100) {
                root.capturedImageB64 = b64
            }
        })
    }

    function sendMessage(text) {
        text = (text || "").trim()
        if (text === "" && root.capturedImageB64 === "") {
            return
        }

        var userDisplayText = text !== "" ? text : i18n("[Screenshot attached]")
        chatModel.append({
            "role": "user",
            "text": userDisplayText,
            "toolInfo": ""
        })

        var userMessageObj = {
            "role": "user",
            "content": text !== "" ? text : "Por favor analiza la captura de pantalla adjunta."
        }
        if (root.capturedImageB64 !== "") {
            userMessageObj["images"] = [root.capturedImageB64]
        }
        root.conversationHistory.push(userMessageObj)
        root.capturedImageB64 = ""
        root.isBusy = true

        var assistantIndex = chatModel.count
        chatModel.append({
            "role": "assistant",
            "text": "",
            "toolInfo": ""
        })

        // Preparar payload para Ollama directo
        var activeLang = (root.preferredLanguage && root.preferredLanguage !== "auto") 
                         ? root.preferredLanguage 
                         : root.detectLanguage(text)

        var systemContent = ""
        if (activeLang === "en") {
            systemContent = "You are Bonsai, a smart local AI assistant integrated into the KDE Plasma 6 desktop. You have access to system tools to interact with the environment: control brightness, volume, timers, launch applications, lock session, organize windows, create folders in the file system, and find or open documents/files on the computer. When the user asks you to perform an action or find a file, always invoke the appropriate tool immediately.\nIMPORTANT: Always reply to the user strictly in English."
        } else {
            systemContent = "Eres Bonsai, un asistente local inteligente integrado en el escritorio KDE Plasma 6. Tienes acceso a herramientas del sistema para interactuar con el entorno: controlar brillo, volumen, temporizadores, abrir aplicaciones, bloquear sesión, organizar ventanas, crear carpetas en el sistema de archivos y buscar o abrir documentos/archivos en el equipo. Si el usuario te pide buscar un documento y abrirlo (o cualquier acción del sistema), invoca siempre la herramienta adecuada de inmediato.\nIMPORTANTE: Responde siempre al usuario estrictamente en español."
        }

        var customPrompt = (Plasmoid.configuration && Plasmoid.configuration.customSystemPrompt) ? Plasmoid.configuration.customSystemPrompt.trim() : ""
        if (customPrompt !== "") {
            systemContent += "\n" + (activeLang === "en" ? "Custom user instructions:\n" : "Instrucciones personalizadas del usuario:\n") + customPrompt
        }

        var messagesToSend = []
        messagesToSend.push({
            "role": "system",
            "content": systemContent
        })
        for (var h = 0; h < root.conversationHistory.length; h++) {
            messagesToSend.push(root.conversationHistory[h])
        }

        var payload = {
            "model": root.currentModel,
            "messages": messagesToSend,
            "stream": true
        }

        // Añadir herramientas si el modelo actual las soporta o si están cargadas
        if (root.toolDefinitions && root.toolDefinitions.length > 0) {
            payload["tools"] = root.toolDefinitions
        }

        var xhr = new XMLHttpRequest()
        xhr.open("POST", root.ollamaUrl + "/api/chat")
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 240000

        var lastProcessed = 0
        var accumulatedToolCalls = []

        xhr.onreadystatechange = function() {
            if (xhr.readyState === 3 || xhr.readyState === 4) {
                var fullResponse = xhr.responseText || ""
                var unread = fullResponse.substring(lastProcessed)
                var lines = unread.split("\n")

                if (xhr.readyState === 3) {
                    var remaining = lines.pop()
                    lastProcessed = fullResponse.length - remaining.length
                } else {
                    lastProcessed = fullResponse.length
                }

                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (line !== "") {
                        try {
                            var data = JSON.parse(line)
                            if (data.message) {
                                if (data.message.content) {
                                    var curText = chatModel.get(assistantIndex).text
                                    chatModel.setProperty(assistantIndex, "text", curText + data.message.content)
                                    chatListView.positionViewAtEnd()
                                }
                                if (data.message.tool_calls && data.message.tool_calls.length > 0) {
                                    for (var t = 0; t < data.message.tool_calls.length; t++) {
                                        accumulatedToolCalls.push(data.message.tool_calls[t])
                                    }
                                }
                            }
                            if (data.done) {
                                root.isBusy = false
                            }
                        } catch (e) {}
                    }
                }
            }

            if (xhr.readyState === 4) {
                root.isBusy = false

                if (xhr.status === 200) {
                    var finalAssistantText = chatModel.get(assistantIndex).text

                    // Si hubo llamadas a herramientas, ejecutarlas mediante el runner local
                    if (accumulatedToolCalls.length > 0) {
                        for (var tc = 0; tc < accumulatedToolCalls.length; tc++) {
                            var call = accumulatedToolCalls[tc]
                            var fnName = call.function.name
                            var fnArgs = JSON.stringify(call.function.arguments || {})
                            var safeArgs = fnArgs.replace(/'/g, "'\\''")

                            root.runCli("python3 '" + root.toolsScriptPath + "' --lang " + activeLang + " call " + fnName + " '" + safeArgs + "'", (code, stdout) => {
                                try {
                                    var res = JSON.parse(stdout.trim())
                                    var defaultActionMsg = (activeLang === "en") ? "Action executed" : "Acción ejecutada"
                                    var info = res.message || (res.success ? defaultActionMsg : res.error)
                                    var curTools = chatModel.get(assistantIndex).toolInfo
                                    var updated = curTools ? (curTools + " • " + info) : info
                                    chatModel.setProperty(assistantIndex, "toolInfo", updated)

                                    // Si el asistente no dijo nada de texto, poner el mensaje de la herramienta
                                    if (chatModel.get(assistantIndex).text === "") {
                                        chatModel.setProperty(assistantIndex, "text", info)
                                    }
                                } catch (e) {}
                            })
                        }
                    }

                    // Guardar en el historial para contexto multi-turno
                    root.conversationHistory.push({
                        "role": "assistant",
                        "content": finalAssistantText
                    })
                } else {
                    var errText = chatModel.get(assistantIndex).text
                    if (errText === "") {
                        chatModel.setProperty(assistantIndex, "text", i18n("Error communicating with Ollama (%1). Make sure it is running.", xhr.status))
                    }
                }
            }
        }

        xhr.send(JSON.stringify(payload))
    }
}
