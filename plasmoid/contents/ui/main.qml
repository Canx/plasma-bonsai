import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami
import "../code/agent.js" as Agent

PlasmoidItem {
    id: root

    readonly property string customAppIcon: Qt.resolvedUrl("../icons/plasma-bonsai.svg")
    Plasmoid.icon: root.customAppIcon
    Plasmoid.title: "Plasma Bonsai Assistant"

    // Configuración de servidores IA OpenAI-compatible (múltiples endpoints)
    property var endpoints: []
    property string activeEndpointId: ""
    property string editingEndpointId: ""
    property string editingDefaultModel: ""
    readonly property string activeEndpointName: {
        var ep = Agent.findEndpointById(root.endpoints, root.activeEndpointId)
        return ep ? ep.name : ""
    }
    property string ollamaUrl: (Plasmoid.configuration && Plasmoid.configuration.ollamaUrl) ? Plasmoid.configuration.ollamaUrl : "http://127.0.0.1:11434"
    property string apiKey: (Plasmoid.configuration && Plasmoid.configuration.apiKey) ? Plasmoid.configuration.apiKey : ""
    readonly property bool isLocalOllama: Agent.isLocalOllamaUrl(root.ollamaUrl)
    property string preferredLanguage: (Plasmoid.configuration && Plasmoid.configuration.preferredLanguage) ? Plasmoid.configuration.preferredLanguage : "auto"
    property string customSystemPrompt: (Plasmoid.configuration && Plasmoid.configuration.customSystemPrompt) ? Plasmoid.configuration.customSystemPrompt : ""
    property bool showSettings: false
    property string connectionTestStatus: ""
    property string connectionTestMessage: ""
    property bool ollamaInstalled: true
    property bool isPullingModel: false
    property string pullStatusText: ""
    property int pullProgress: -1
    property var activePullXhr: null
    property bool ollamaConnected: false
    property bool isBusy: false
    property string busyStatus: "thinking"
    property var activeXhr: null
    property bool cancelRequested: false
    property int requestGeneration: 0
    property int activeAssistantIndex: -1
    signal scrollToBottomRequested()
    property bool isRecordingVoice: false
    property bool isPinned: false
    property bool isPickingFile: false
    hideOnWindowDeactivate: !root.isPinned && !root.isPickingFile
    property string capturedImageB64: ""
    property string attachedFilePath: ""
    property string attachedFileName: ""
    property string attachedFileType: ""
    property string attachedFileText: ""
    property var availableModels: []
    property string currentModel: ""
    property var toolDefinitions: []
    property var conversationHistory: []

    readonly property bool isEnglish: {
        if (root.preferredLanguage === "en") return true
        if (root.preferredLanguage === "es") return false
        var loc = ""
        try {
            loc = (Qt.locale() && Qt.locale().name) ? Qt.locale().name.toLowerCase() : ""
        } catch (e) {}
        // Si es 'auto', solo usar español si el sistema es explícitamente español; por defecto siempre inglés
        return (loc.indexOf("es") !== 0)
    }

    function tr(enText, esText) {
        return root.isEnglish ? enText : esText
    }

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

    ListModel {
        id: endpointComboModel
    }

    ListModel {
        id: settingsModelsList
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

        Shortcut {
            sequence: "Escape"
            enabled: root.isBusy
            onActivated: root.cancelRequest()
        }

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

                // Indicador compacto clicable de endpoint + modelo activo (abre menú rápido al pulsar)
                PlasmaComponents.ToolButton {
                    id: activeModelBadge
                    Layout.fillWidth: true
                    Layout.minimumWidth: Kirigami.Units.gridUnit * 5
                    flat: true
                    ToolTip.text: (root.activeEndpointName || root.ollamaUrl)
                        + (root.currentModel ? ("\n" + root.tr("Model: ", "Modelo: ") + root.currentModel) : "")
                        + "\n" + root.tr("Click to switch endpoint or model", "Pulsa para cambiar de endpoint o modelo")
                    ToolTip.visible: hovered
                    onClicked: {
                        if (quickSwitchMenu.opened) {
                            quickSwitchMenu.close()
                        } else {
                            quickSwitchMenu.popup(activeModelBadge, 0, activeModelBadge.height)
                        }
                    }

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.smallSpacing

                        Rectangle {
                            width: Kirigami.Units.gridUnit * 0.45
                            height: width
                            radius: width / 2
                            color: root.ollamaConnected ? "#27ae60" : "#e74c3c"
                            Layout.alignment: Qt.AlignVCenter
                        }

                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.85
                            text: {
                                var epName = root.activeEndpointName || root.tr("Server", "Servidor")
                                return root.currentModel ? (epName + " · " + root.currentModel) : epName
                            }
                        }

                        Kirigami.Icon {
                            source: "arrow-down"
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small * 0.75
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small * 0.75
                            opacity: 0.65
                        }
                    }

                    Menu {
                        id: quickSwitchMenu
                        width: Math.max(activeModelBadge.width, Kirigami.Units.gridUnit * 13)

                        // Sección de Endpoints (si hay más de uno)
                        Instantiator {
                            model: root.endpoints.length > 1 ? endpointComboModel : null
                            delegate: MenuItem {
                                text: "🔌 " + model.name
                                checkable: true
                                checked: model.id === root.activeEndpointId
                                onTriggered: root.selectEndpoint(model.id)
                            }
                            onObjectAdded: (index, object) => quickSwitchMenu.insertItem(index, object)
                            onObjectRemoved: (index, object) => quickSwitchMenu.removeItem(object)
                        }

                        MenuSeparator {
                            visible: root.endpoints.length > 1 && modelComboModel.count > 0
                        }

                        // Sección de Modelos del endpoint activo
                        Instantiator {
                            model: modelComboModel
                            delegate: MenuItem {
                                text: model.text
                                checkable: true
                                checked: model.text === root.currentModel
                                onTriggered: {
                                    root.currentModel = model.text
                                    root.saveDefaultModelForActiveEndpoint(root.currentModel)
                                }
                            }
                            onObjectAdded: (index, object) => {
                                var offset = (root.endpoints.length > 1) ? (endpointComboModel.count + 1) : 0
                                quickSwitchMenu.insertItem(offset + index, object)
                            }
                            onObjectRemoved: (index, object) => quickSwitchMenu.removeItem(object)
                        }

                        MenuSeparator {
                            visible: modelComboModel.count > 0 || root.endpoints.length > 1
                        }

                        MenuItem {
                            icon.name: "configure"
                            text: root.tr("Manage endpoints…", "Gestionar endpoints…")
                            onTriggered: {
                                root.showSettings = true
                                root.loadEndpointIntoSettings(root.activeEndpointId)
                            }
                        }
                    }
                }

                PlasmaComponents.ToolButton {
                    icon.name: root.isPinned ? "window-pin" : "window-unpin"
                    text: root.isPinned ? root.tr("Unpin window", "Desanclar ventana") : root.tr("Pin window", "Fijar ventana")
                    display: PlasmaComponents.AbstractButton.IconOnly
                    ToolTip.text: root.isPinned ? root.tr("Unpin window (close on outside click)", "Desanclar ventana (se cierra al hacer clic fuera)") : root.tr("Pin window (keep visible on screen)", "Fijar ventana (mantener visible en pantalla)")
                    ToolTip.visible: hovered
                    onClicked: root.isPinned = !root.isPinned
                }

                PlasmaComponents.ToolButton {
                    icon.name: "edit-clear-all"
                    text: root.tr("Clear", "Limpiar")
                    display: PlasmaComponents.AbstractButton.IconOnly
                    ToolTip.text: root.tr("Clear conversation", "Limpiar conversación")
                    ToolTip.visible: hovered
                    onClicked: root.clearChat()
                }

                PlasmaComponents.ToolButton {
                    icon.name: root.showSettings ? "chat" : "configure"
                    text: root.showSettings ? root.tr("Chat", "Chat") : root.tr("Configure", "Configurar")
                    display: PlasmaComponents.AbstractButton.IconOnly
                    ToolTip.text: root.showSettings ? root.tr("Back to chat", "Volver al chat") : root.tr("Configure Bonsai", "Configurar Bonsai")
                    ToolTip.visible: hovered
                    onClicked: {
                        root.showSettings = !root.showSettings
                        if (root.showSettings) {
                            root.loadEndpointIntoSettings(root.activeEndpointId)
                        }
                    }
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

                // Banner / asistente de primer inicio si no hay servidor conectado o no hay modelos
                Rectangle {
                    visible: !root.ollamaConnected || (root.ollamaConnected && root.availableModels.length === 0)
                    Layout.fillWidth: true
                    implicitHeight: onboardingColumn.implicitHeight + 16
                    radius: 6
                    color: !root.ollamaConnected
                        ? ((root.isLocalOllama && !root.ollamaInstalled) ? "#2c3e50" : "#c0392b")
                        : (root.isLocalOllama ? "#2c3e50" : "#d35400")

                    ColumnLayout {
                        id: onboardingColumn
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            font.bold: true
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            color: "#ffffff"
                            wrapMode: Text.Wrap
                            text: !root.ollamaConnected
                                  ? (root.isLocalOllama
                                      ? (!root.ollamaInstalled
                                          ? root.tr("🌱 Set up your AI backend", "🌱 Configura tu motor de IA")
                                          : root.tr("⚠️ Ollama is not running on localhost:11434", "⚠️ Ollama no se está ejecutando en localhost:11434"))
                                      : root.tr("⚠️ Cannot connect to AI server", "⚠️ No se puede conectar al servidor IA"))
                                  : (root.isLocalOllama
                                      ? root.tr("📦 Download a starter model", "📦 Descarga un modelo para empezar")
                                      : root.tr("⚠️ No models available on server", "⚠️ No hay modelos disponibles en el servidor"))
                        }

                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                            color: "#ffffff"
                            wrapMode: Text.Wrap
                            text: !root.ollamaConnected
                                  ? (root.isLocalOllama
                                      ? (!root.ollamaInstalled
                                          ? root.tr("Install Ollama to run models privately on your PC, or connect a remote server (LiteLLM, OpenAI, vLLM…).", "Instala Ollama para ejecutar modelos en local con privacidad, o conecta un servidor remoto (LiteLLM, OpenAI, vLLM…).")
                                          : root.tr("Start Ollama locally or configure a remote server.", "Inicia Ollama en local o configura un servidor remoto."))
                                      : root.tr("Check the server URL and API key in Settings.", "Revisa la URL del servidor y la API key en Ajustes."))
                                  : (root.isLocalOllama
                                      ? root.tr("Pick a model to download directly with Ollama:", "Elige un modelo para descargarlo directamente con Ollama:")
                                      : root.tr("Verify that the server exposes models at /v1/models.", "Verifica que el servidor exponga modelos en /v1/models."))
                        }

                        // Botones cuando no hay conexión
                        RowLayout {
                            visible: !root.ollamaConnected
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            PlasmaComponents.Button {
                                visible: root.isLocalOllama && !root.ollamaInstalled
                                icon.name: "download"
                                text: root.tr("Install Ollama", "Instalar Ollama")
                                onClicked: root.installOllama()
                            }

                            PlasmaComponents.Button {
                                visible: root.isLocalOllama && root.ollamaInstalled
                                icon.name: "media-playback-start"
                                text: root.tr("Start Ollama", "Iniciar Ollama")
                                onClicked: root.startOllamaService()
                            }

                            PlasmaComponents.Button {
                                icon.name: "configure"
                                text: root.isLocalOllama
                                    ? root.tr("Remote Server…", "Servidor remoto…")
                                    : root.tr("Settings", "Ajustes")
                                onClicked: root.showSettings = true
                            }
                        }

                        // Selector y descarga directa cuando Ollama local está activo pero sin modelos
                        RowLayout {
                            visible: root.ollamaConnected && root.availableModels.length === 0 && root.isLocalOllama
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            PlasmaComponents.ComboBox {
                                id: starterModelCombo
                                Layout.fillWidth: true
                                enabled: !root.isPullingModel
                                textRole: "text"
                                model: [
                                    { text: root.tr("bonsai-2:2b (Light / Vision + Tools)", "bonsai-2:2b (Ligero / Visión + Herramientas)"), value: "bonsai-2:2b" },
                                    { text: root.tr("lfm3-omni:2b (Multimodal / Native Voice)", "lfm3-omni:2b (Multimodal / Voz nativa)"), value: "lfm3-omni:2b" },
                                    { text: root.tr("qwen3:4b (Balanced / Best Tools)", "qwen3:4b (Equilibrado / Mejores herramientas)"), value: "qwen3:4b" }
                                ]
                            }

                            PlasmaComponents.Button {
                                visible: !root.isPullingModel
                                icon.name: "download"
                                text: root.tr("Download", "Descargar")
                                onClicked: {
                                    var sel = starterModelCombo.model[starterModelCombo.currentIndex]
                                    if (sel && sel.value) {
                                        root.pullModel(sel.value)
                                    }
                                }
                            }

                            PlasmaComponents.Button {
                                visible: root.isPullingModel
                                icon.name: "process-stop"
                                text: root.tr("Cancel", "Cancelar")
                                onClicked: root.cancelPullModel()
                            }
                        }

                        // Barra de progreso durante la descarga del modelo
                        ProgressBar {
                            visible: root.isPullingModel
                            Layout.fillWidth: true
                            from: 0
                            to: 100
                            value: root.pullProgress >= 0 ? root.pullProgress : 0
                            indeterminate: root.pullProgress < 0
                        }

                        PlasmaComponents.Label {
                            visible: root.pullStatusText !== ""
                            Layout.fillWidth: true
                            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
                            color: "#ecf0f1"
                            wrapMode: Text.Wrap
                            text: root.pullStatusText
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

                Connections {
                    target: root
                    function onScrollToBottomRequested() {
                        Qt.callLater(function() {
                            chatListView.positionViewAtEnd()
                        })
                    }
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
                                    text: bubbleDelegate.isUser ? root.tr("You", "Tú") : "Bonsai"
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
                                    ToolTip.text: root.tr("Listen to response", "Escuchar respuesta")
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
                                    ToolTip.text: root.tr("Copy response to clipboard", "Copiar respuesta al portapapeles")
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

            // Vista previa de archivo o captura adjunta
            RowLayout {
                visible: root.capturedImageB64 !== "" || root.attachedFileName !== ""
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Rectangle {
                    color: Kirigami.Theme.highlightColor
                    radius: 3
                    implicitWidth: attachBadge.implicitWidth + 12
                    implicitHeight: attachBadge.implicitHeight + 6

                    PlasmaComponents.Label {
                        id: attachBadge
                        anchors.centerIn: parent
                        text: {
                            if (root.attachedFileType === "document") {
                                return "📄 " + root.attachedFileName
                            } else if (root.attachedFileName !== "") {
                                return "🖼️ " + root.attachedFileName
                            } else {
                                return "📸 " + root.tr("Screenshot ready for analysis", "Captura lista para analizar")
                            }
                        }
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        color: Kirigami.Theme.highlightedTextColor
                    }
                }

                PlasmaComponents.ToolButton {
                    icon.name: "dialog-close"
                    display: PlasmaComponents.AbstractButton.IconOnly
                    ToolTip.text: root.tr("Remove attachment", "Quitar archivo adjunto")
                    ToolTip.visible: hovered
                    onClicked: root.clearAttachment()
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
                    Layout.fillWidth: true
                }

                PlasmaComponents.ToolButton {
                    id: cancelBtn
                    visible: root.isBusy
                    icon.name: "process-stop"
                    text: root.tr("Stop", "Parar")
                    ToolTip.text: root.tr("Cancel the current request (Esc)", "Cancelar la petición actual (Esc)")
                    ToolTip.visible: hovered
                    onClicked: root.cancelRequest()
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
                    ToolTip.text: root.isRecordingVoice ? root.tr("Stop recording and send", "Detener grabación y enviar") : root.tr("Voice input (Push-to-talk)", "Entrada de voz (Pulsar para hablar)")
                    ToolTip.visible: hovered
                    enabled: !root.isBusy
                    onClicked: root.toggleVoiceInput()
                }

                PlasmaComponents.ToolButton {
                    icon.name: "camera-photo"
                    ToolTip.text: root.tr("Capture screenshot to analyze", "Hacer captura de pantalla para analizar")
                    ToolTip.visible: hovered
                    enabled: !root.isBusy && !root.isRecordingVoice
                    onClicked: root.requestScreenshot()
                }

                PlasmaComponents.ToolButton {
                    id: attachBtn
                    icon.name: "mail-attachment"
                    ToolTip.text: root.tr("Attach file or document (PDF, code, text, image)", "Adjuntar archivo o documento (PDF, código, texto, imagen)")
                    ToolTip.visible: hovered
                    enabled: !root.isBusy && !root.isRecordingVoice
                    onClicked: root.requestAttachFile()
                }

                PlasmaComponents.TextField {
                    id: promptInput
                    Layout.fillWidth: true
                    placeholderText: root.getPlaceholderText()
                    enabled: !root.isBusy && !root.isRecordingVoice
                    onAccepted: {
                        var val = promptInput.text.trim()
                        if (val !== "" || root.capturedImageB64 !== "" || root.attachedFileName !== "") {
                            root.sendMessage(val)
                            promptInput.text = ""
                        }
                    }
                }

                PlasmaComponents.Button {
                    id: sendBtn
                    icon.name: "document-send"
                    text: root.tr("Send", "Enviar")
                    enabled: !root.isBusy && (promptInput.text.trim().length > 0 || root.capturedImageB64 !== "" || root.attachedFileName !== "")
                    onClicked: {
                        var val = promptInput.text.trim()
                        if (val !== "" || root.capturedImageB64 !== "" || root.attachedFileName !== "") {
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
                    text: root.tr("⚙️ Bonsai Settings", "⚙️ Ajustes de Bonsai")
                    font.bold: true
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.15
                    Layout.fillWidth: true
                }

                PlasmaComponents.Button {
                    icon.name: "go-previous"
                    text: root.tr("Back", "Volver")
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

                    // 1. Selector y gestión de Endpoints
                    PlasmaComponents.Label {
                        text: root.tr("AI Endpoints:", "Servidores IA (Endpoints):")
                        font.bold: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents.ComboBox {
                            id: settingsEndpointCombo
                            Layout.fillWidth: true
                            model: endpointComboModel
                            textRole: "name"
                            currentIndex: {
                                for (var i = 0; i < endpointComboModel.count; i++) {
                                    if (endpointComboModel.get(i).id === root.editingEndpointId) return i
                                }
                                return 0
                            }
                            onActivated: {
                                var item = endpointComboModel.get(index)
                                if (item && item.id) {
                                    root.loadEndpointIntoSettings(item.id)
                                }
                            }
                        }

                        PlasmaComponents.ToolButton {
                            icon.name: "list-add"
                            ToolTip.text: root.tr("Add new endpoint", "Añadir nuevo endpoint")
                            ToolTip.visible: hovered
                            onClicked: {
                                var hasLocalOllama = false
                                for (var i = 0; i < root.endpoints.length; i++) {
                                    if (Agent.isLocalOllamaUrl(root.endpoints[i].url)) {
                                        hasLocalOllama = true
                                        break
                                    }
                                }
                                var newId = "ep_" + Date.now()
                                root.endpoints = Agent.upsertEndpoint(root.endpoints, {
                                    "id": newId,
                                    "name": hasLocalOllama ? root.tr("New Server", "Nuevo servidor") : "Ollama Local",
                                    "url": hasLocalOllama ? "http://localhost:4000" : "http://127.0.0.1:11434",
                                    "apiKey": "",
                                    "defaultModel": ""
                                })
                                root.syncEndpointComboModel()
                                root.loadEndpointIntoSettings(newId)
                            }
                        }

                        PlasmaComponents.ToolButton {
                            icon.name: "edit-delete"
                            enabled: root.endpoints.length > 1
                            ToolTip.text: root.tr("Delete selected endpoint", "Eliminar endpoint seleccionado")
                            ToolTip.visible: hovered
                            onClicked: {
                                var targetId = root.editingEndpointId || root.activeEndpointId
                                root.endpoints = Agent.deleteEndpoint(root.endpoints, targetId)
                                root.persistEndpoints()
                                root.syncEndpointComboModel()
                                var nextEp = Agent.findEndpointById(root.endpoints, root.activeEndpointId)
                                if (nextEp) {
                                    root.selectEndpoint(nextEp.id)
                                    root.loadEndpointIntoSettings(nextEp.id)
                                }
                            }
                        }
                    }

                    // 1a. Nombre del Endpoint
                    PlasmaComponents.Label {
                        text: root.tr("Endpoint Name:", "Nombre del endpoint:")
                        font.bold: true
                    }

                    PlasmaComponents.TextField {
                        id: settingsNameInput
                        Layout.fillWidth: true
                        text: root.getEditingEndpointField("name")
                        placeholderText: "Ollama Local / LiteLLM"
                    }

                    // 1b. URL del Servidor (Ollama, LiteLLM, vLLM, OpenAI-compatible)
                    PlasmaComponents.Label {
                        text: root.tr("Server URL (Ollama / LiteLLM / OpenAI):", "URL del servidor (Ollama / LiteLLM / OpenAI):")
                        font.bold: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents.TextField {
                            id: settingsUrlInput
                            Layout.fillWidth: true
                            text: root.getEditingEndpointField("url")
                            placeholderText: "http://127.0.0.1:11434"
                        }

                        PlasmaComponents.Button {
                            id: settingsTestButton
                            enabled: root.connectionTestStatus !== "testing"
                            text: root.connectionTestStatus === "testing" ? root.tr("Testing…", "Probando…") : root.tr("Test", "Probar")
                            icon.name: "network-connect"
                            onClicked: {
                                var testUrl = settingsUrlInput.text.trim() || "http://127.0.0.1:11434"
                                var testKey = settingsApiKeyInput.text.trim()
                                root.connectionTestStatus = "testing"
                                root.connectionTestMessage = root.tr("Testing connection to " + Agent.buildModelsUrl(testUrl) + "…", "Probando conexión a " + Agent.buildModelsUrl(testUrl) + "…")
                                root.testEndpointConnection(testUrl, testKey, function(ok, status, detail, names) {
                                    if (ok) {
                                        root.populateSettingsModelsList(names || [], root.editingDefaultModel)
                                        root.connectionTestStatus = "ok"
                                        root.connectionTestMessage = root.tr(
                                            "✓ Connected (" + detail + " models found)",
                                            "✓ Conectado (" + detail + " modelos encontrados)"
                                        )
                                    } else {
                                        root.connectionTestStatus = "error"
                                        if (status === 401 || status === 403) {
                                            root.connectionTestMessage = root.tr(
                                                "✗ Authentication failed (HTTP " + status + "). Check your API key.",
                                                "✗ Error de autenticación (HTTP " + status + "). Revisa tu API Key."
                                            )
                                        } else if (status === 404) {
                                            root.connectionTestMessage = root.tr(
                                                "✗ Endpoint /v1/models not found (HTTP 404). Check the URL.",
                                                "✗ Endpoint /v1/models no encontrado (HTTP 404). Revisa la URL."
                                            )
                                        } else if (status === 0) {
                                            root.connectionTestMessage = root.tr(
                                                "✗ Could not reach server (timeout or network error).",
                                                "✗ No se pudo conectar con el servidor (tiempo agotado o error de red)."
                                            )
                                        } else if (detail === "invalid_json") {
                                            root.connectionTestMessage = root.tr(
                                                "✗ Server replied, but not with valid JSON.",
                                                "✗ El servidor respondió, pero no con JSON válido."
                                            )
                                        } else {
                                            root.connectionTestMessage = root.tr(
                                                "✗ Server error (HTTP " + status + ").",
                                                "✗ Error del servidor (HTTP " + status + ")."
                                            )
                                        }
                                    }
                                })
                            }
                        }
                    }

                    // 1c. API Key (opcional para servidores remotos)
                    PlasmaComponents.Label {
                        text: root.tr("API Key (optional):", "API Key (opcional):")
                        font.bold: true
                    }

                    PlasmaComponents.TextField {
                        id: settingsApiKeyInput
                        Layout.fillWidth: true
                        text: root.getEditingEndpointField("apiKey")
                        echoMode: TextInput.Password
                        placeholderText: "sk-..."
                    }

                    // 1d. Modelo por defecto para este endpoint (desplegable con modelos detectados)
                    PlasmaComponents.Label {
                        text: root.tr("Default Model for this endpoint:", "Modelo por defecto para este endpoint:")
                        font.bold: true
                    }

                    PlasmaComponents.ComboBox {
                        id: settingsDefaultModelCombo
                        Layout.fillWidth: true
                        model: settingsModelsList
                        textRole: "text"
                        currentIndex: {
                            for (var i = 0; i < settingsModelsList.count; i++) {
                                if (settingsModelsList.get(i).value === root.editingDefaultModel) return i
                            }
                            return 0
                        }
                        onActivated: {
                            var item = settingsModelsList.get(index)
                            root.editingDefaultModel = item ? item.value : ""
                        }
                    }

                    // Resultado del botón Probar
                    PlasmaComponents.Label {
                        visible: root.connectionTestMessage !== ""
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        font.bold: root.connectionTestStatus !== "testing"
                        color: root.connectionTestStatus === "ok"
                            ? "#27ae60"
                            : (root.connectionTestStatus === "error" ? "#e74c3c" : Kirigami.Theme.disabledTextColor)
                        text: root.connectionTestMessage
                    }

                    // 2. Idioma de Respuesta
                    PlasmaComponents.Label {
                        text: root.tr("Response Language:", "Idioma de respuesta:")
                        font.bold: true
                    }

                    PlasmaComponents.ComboBox {
                        id: settingsLangCombo
                        Layout.fillWidth: true
                        textRole: "text"
                        model: [
                            { text: root.tr("Automatic (match user input)", "Automático (según lo escrito)"), value: "auto" },
                            { text: root.tr("Always English", "Siempre Inglés"), value: "en" },
                            { text: root.tr("Always Spanish", "Siempre Español"), value: "es" }
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
                        text: root.tr("Custom Instructions (System Prompt):", "Instrucciones personalizadas (System Prompt):")
                        font.bold: true
                    }

                    PlasmaComponents.TextArea {
                        id: settingsCustomPromptInput
                        Layout.fillWidth: true
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 5
                        text: root.customSystemPrompt
                        placeholderText: root.tr("Optional instructions (e.g. 'Always answer in English, be concise and use bullet points').", "Instrucciones opcionales (ej: 'Responde siempre de forma concisa y usa viñetas').")
                        wrapMode: TextEdit.Wrap
                    }

                    Item { Layout.fillHeight: true }

                    // 4. Botón Guardar
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents.Button {
                            icon.name: "dialog-ok-apply"
                            text: root.tr("Save Settings", "Guardar ajustes")
                            Layout.fillWidth: true
                            onClicked: {
                                var epId = root.editingEndpointId || root.activeEndpointId || "default"
                                var epUrl = settingsUrlInput.text.trim() || "http://127.0.0.1:11434"
                                var epName = settingsNameInput.text.trim()
                                var epKey = settingsApiKeyInput.text.trim()
                                var epDefModel = root.editingDefaultModel.trim()

                                root.endpoints = Agent.upsertEndpoint(root.endpoints, {
                                    "id": epId,
                                    "name": epName,
                                    "url": epUrl,
                                    "apiKey": epKey,
                                    "defaultModel": epDefModel
                                })
                                root.syncEndpointComboModel()

                                var sel = settingsLangCombo.model[settingsLangCombo.currentIndex]
                                root.preferredLanguage = sel ? sel.value : "auto"
                                root.customSystemPrompt = settingsCustomPromptInput.text.trim()

                                if (Plasmoid.configuration) {
                                    Plasmoid.configuration.preferredLanguage = root.preferredLanguage
                                    Plasmoid.configuration.customSystemPrompt = root.customSystemPrompt
                                }

                                if (chatModel.count > 0 && chatModel.get(0).role === "welcome") {
                                    chatModel.setProperty(0, "text", root.getWelcomeMessage())
                                }

                                root.connectionTestStatus = ""
                                root.connectionTestMessage = ""
                                root.selectEndpoint(epId)
                                root.showSettings = false
                            }
                        }
                    }

                    // 5. Apoyar el proyecto / GitHub Sponsors
                    PlasmaComponents.ToolButton {
                        text: root.tr("💖 Support on GitHub Sponsors", "💖 Apoyar en GitHub Sponsors")
                        icon.name: "help-donate"
                        Layout.fillWidth: true
                        onClicked: Qt.openUrlExternally("https://github.com/sponsors/Canx")
                    }

                    // 6. Versión instalada (leída de metadata.json)
                    PlasmaComponents.Label {
                        id: versionLabel
                        text: root.tr("Version", "Versión") + " " + Plasmoid.metaData.version
                        opacity: 0.6
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        Layout.alignment: Qt.AlignHCenter
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
        return root.tr(
            "Hello! I am Bonsai, your native local assistant for KDE Plasma. I can answer questions, analyze screenshots and documents, or control desktop settings completely offline via Ollama.",
            "¡Hola! Soy Bonsai, tu asistente local nativo para KDE Plasma. Puedo responder preguntas, analizar capturas y documentos o controlar el escritorio completamente en local mediante Ollama."
        )
    }

    function getClearedMessage() {
        return root.tr(
            "Conversation cleared. How can I help you?",
            "Conversación reiniciada. ¿En qué te puedo ayudar?"
        )
    }

    function getPlaceholderText() {
        if (root.isRecordingVoice) {
            return root.tr("🔴 Listening… Click mic again to send", "🔴 Escuchando… Pulsa el micrófono para enviar")
        }
        return root.tr("Ask or request an action from Bonsai…", "Pregunta o pide una acción a Bonsai…")
    }

    function finalizeCancelled(assistantIndex) {
        if (!root.isBusy) return
        root.isBusy = false
        root.busyStatus = "thinking"
        root.activeXhr = null
        root.cancelRequested = false

        if (assistantIndex < 0 || assistantIndex >= chatModel.count) return
        var partial = chatModel.get(assistantIndex).text
        if (partial === "") {
            chatModel.setProperty(assistantIndex, "text", root.tr("⏹ Request cancelled.", "⏹ Petición cancelada."))
            // Sin respuesta: retirar la pregunta o mensajes de herramienta sin cerrar
            if (root.conversationHistory.length > 0 && root.conversationHistory[root.conversationHistory.length - 1].role === "user") {
                root.conversationHistory.pop()
            } else if (root.conversationHistory.length > 0 && root.conversationHistory[root.conversationHistory.length - 1].role === "tool") {
                root.conversationHistory.push({"role": "assistant", "content": root.tr("[Request cancelled]", "[Petición cancelada]")})
            }
        } else {
            chatModel.setProperty(assistantIndex, "text", partial + "\n\n" + root.tr("⏹ _(cancelled)_", "⏹ _(cancelado)_"))
            root.conversationHistory.push({"role": "assistant", "content": partial})
        }
    }

    function cancelRequest() {
        if (!root.isBusy && root.activeXhr === null) return
        root.requestGeneration++
        root.cancelRequested = true
        if (root.activeXhr !== null) {
            root.activeXhr.abort()
        } else {
            root.finalizeCancelled(root.activeAssistantIndex)
        }
        root.unloadModel()
    }

    // Ollama no interrumpe el procesado del prompt al cerrarse la conexión:
    // descargar el modelo (keep_alive: 0) detiene el runner y libera la CPU.
    function unloadModel() {
        if (!root.isLocalOllama || root.currentModel === "") return
        var x = new XMLHttpRequest()
        x.open("POST", Agent.normalizeBaseUrl(root.ollamaUrl) + "/api/generate")
        x.setRequestHeader("Content-Type", "application/json")
        x.send(JSON.stringify({"model": root.currentModel, "keep_alive": 0}))
    }

    function getThinkingText() {
        if (root.busyStatus === "running_tool") {
            return root.tr("Bonsai is running tool…", "Bonsai está ejecutando herramienta…")
        }
        return root.tr("Bonsai is thinking…", "Bonsai está pensando…")
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

        // Inicializar endpoints configurados, esquema de herramientas y comprobar si Ollama está instalado
        root.initEndpoints()
        root.loadToolSchema()
        root.checkOllamaInstalled()
    }

    function initEndpoints() {
        var epJson = (Plasmoid.configuration && Plasmoid.configuration.endpointsJson) ? Plasmoid.configuration.endpointsJson : ""
        var savedActive = (Plasmoid.configuration && Plasmoid.configuration.activeEndpointId) ? Plasmoid.configuration.activeEndpointId : ""
        var legacyUrl = (Plasmoid.configuration && Plasmoid.configuration.ollamaUrl) ? Plasmoid.configuration.ollamaUrl : "http://127.0.0.1:11434"
        var legacyKey = (Plasmoid.configuration && Plasmoid.configuration.apiKey) ? Plasmoid.configuration.apiKey : ""
        var legacyModel = (Plasmoid.configuration && Plasmoid.configuration.defaultModel) ? Plasmoid.configuration.defaultModel : ""

        root.endpoints = Agent.loadEndpoints(epJson, legacyUrl, legacyKey, legacyModel)
        root.syncEndpointComboModel()

        var active = Agent.findEndpointById(root.endpoints, savedActive)
        if (active) {
            root.activeEndpointId = active.id
            root.editingEndpointId = active.id
            root.ollamaUrl = active.url
            root.apiKey = active.apiKey
            root.currentModel = active.defaultModel || ""
        }
    }

    function syncEndpointComboModel() {
        endpointComboModel.clear()
        for (var i = 0; i < root.endpoints.length; i++) {
            endpointComboModel.append({
                "id": root.endpoints[i].id,
                "name": root.endpoints[i].name
            })
        }
    }

    function persistEndpoints() {
        if (Plasmoid.configuration) {
            Plasmoid.configuration.endpointsJson = JSON.stringify(root.endpoints)
            Plasmoid.configuration.activeEndpointId = root.activeEndpointId
            Plasmoid.configuration.ollamaUrl = root.ollamaUrl
            Plasmoid.configuration.apiKey = root.apiKey
        }
    }

    function getEditingEndpointField(field) {
        var ep = Agent.findEndpointById(root.endpoints, root.editingEndpointId || root.activeEndpointId)
        return (ep && ep[field] !== undefined) ? String(ep[field]) : ""
    }

    function populateSettingsModelsList(names, selectedModel) {
        settingsModelsList.clear()
        settingsModelsList.append({
            "text": root.tr("Auto (first available)", "Automático (primero disponible)"),
            "value": ""
        })
        var foundSelected = (selectedModel === "")
        for (var i = 0; i < names.length; i++) {
            settingsModelsList.append({ "text": names[i], "value": names[i] })
            if (names[i] === selectedModel) foundSelected = true
        }
        if (!foundSelected && selectedModel !== "") {
            settingsModelsList.append({ "text": selectedModel, "value": selectedModel })
        }
    }

    function loadEndpointIntoSettings(epId) {
        root.editingEndpointId = epId
        var ep = Agent.findEndpointById(root.endpoints, epId)
        root.editingDefaultModel = ep ? (ep.defaultModel || "") : ""
        root.connectionTestStatus = ""
        root.connectionTestMessage = ""
        root.populateSettingsModelsList(
            (ep && ep.id === root.activeEndpointId) ? (root.availableModels || []) : [],
            root.editingDefaultModel
        )
        if (ep && ep.url) {
            var targetId = ep.id
            root.testEndpointConnection(ep.url, ep.apiKey, function(ok, status, detail, names) {
                if (ok && root.editingEndpointId === targetId) {
                    root.populateSettingsModelsList(names || [], root.editingDefaultModel)
                }
            })
        }
    }

    function selectEndpoint(epId) {
        var ep = Agent.findEndpointById(root.endpoints, epId)
        if (!ep) return
        root.activeEndpointId = ep.id
        root.editingEndpointId = ep.id
        root.ollamaUrl = ep.url
        root.apiKey = ep.apiKey
        root.currentModel = ep.defaultModel || ""
        root.availableModels = []
        modelComboModel.clear()
        root.persistEndpoints()
        root.checkOllamaHealth()
    }

    function saveDefaultModelForActiveEndpoint(modelName) {
        var ep = Agent.findEndpointById(root.endpoints, root.activeEndpointId)
        if (!ep || ep.defaultModel === modelName) return
        root.endpoints = Agent.upsertEndpoint(root.endpoints, {
            "id": ep.id,
            "name": ep.name,
            "url": ep.url,
            "apiKey": ep.apiKey,
            "defaultModel": modelName
        })
        root.persistEndpoints()
    }

    function testEndpointConnection(url, apiKey, onResult) {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", Agent.buildModelsUrl(url))
        var key = (apiKey || "").trim()
        if (key !== "") {
            xhr.setRequestHeader("Authorization", "Bearer " + key)
        }
        xhr.timeout = 6000
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var names = Agent.parseModelsResponse(xhr.responseText)
                        if (onResult) onResult(true, 200, names.length, names)
                    } catch (e) {
                        if (onResult) onResult(false, 200, "invalid_json", [])
                    }
                } else {
                    if (onResult) onResult(false, xhr.status, xhr.responseText || "", [])
                }
            }
        }
        xhr.send()
    }

    function checkOllamaInstalled() {
        root.runCli("python3 '" + root.toolsScriptPath + "' check_ollama", (code, stdout) => {
            if (code === 0 && stdout.trim() !== "") {
                try {
                    var res = JSON.parse(stdout.trim())
                    root.ollamaInstalled = !!res.installed
                } catch (e) {}
            }
        })
    }

    function installOllama() {
        root.runCli("python3 '" + root.toolsScriptPath + "' install_ollama", (code, stdout) => {
            try {
                var res = JSON.parse((stdout || "").trim())
                if (!res.success && res.error) {
                    root.pullStatusText = res.error
                }
            } catch (e) {}
        })
    }

    function pullModel(modelName) {
        if (!modelName || root.isPullingModel) return
        root.isPullingModel = true
        root.pullProgress = -1
        root.pullStatusText = root.tr("Starting download of " + modelName + "…", "Iniciando descarga de " + modelName + "…")

        Agent.pullOllamaModel({
            "ollamaUrl": root.ollamaUrl,
            "model": modelName,
            "onXhrCreated": function(xhr) {
                root.activePullXhr = xhr
            },
            "onProgress": function(statusText, percent) {
                root.pullProgress = percent
                root.pullStatusText = (percent >= 0) ? (statusText + " (" + percent + "%)") : statusText
            },
            "onComplete": function() {
                root.isPullingModel = false
                root.activePullXhr = null
                root.pullProgress = 100
                root.pullStatusText = ""
                root.checkOllamaHealth()
            },
            "onError": function(errMsg) {
                root.isPullingModel = false
                root.activePullXhr = null
                root.pullProgress = -1
                if (errMsg === "cancelled") {
                    root.pullStatusText = root.tr("Download cancelled.", "Descarga cancelada.")
                } else {
                    root.pullStatusText = root.tr("Download failed: " + errMsg, "Error en la descarga: " + errMsg)
                }
            }
        })
    }

    function cancelPullModel() {
        if (root.activePullXhr !== null) {
            root.activePullXhr.abort()
        }
    }

    function copyToClipboard(text) {
        if (!text) return
        var safe = text.replace(/'/g, "'\\''")
        root.runCli("python3 '" + root.toolsScriptPath + "' clipboard set '" + safe + "'", null)
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
            // Detener captura: enviar audio directo si el modelo soporta audio nativo,
            // o transcribir con Whisper (con fallback a audio nativo si Whisper no está instalado)
            root.isRecordingVoice = false
            root.isBusy = true
            root.runCli("python3 '" + root.toolsScriptPath + "' record stop", (code, stdout) => {
                var sendNativeAudio = function() {
                    root.runCli("python3 '" + root.toolsScriptPath + "' read_audio", (codeA, stdoutA) => {
                        root.isBusy = false
                        try {
                            var resA = JSON.parse((stdoutA || "").trim())
                            if (resA.success && resA.base64_audio) {
                                root.sendMessage("", resA.base64_audio)
                            }
                        } catch (e) {}
                    })
                }

                if (Agent.isNativeAudioModel(root.currentModel)) {
                    sendNativeAudio()
                    return
                }

                root.runCli("python3 '" + root.toolsScriptPath + "' transcribe", (code2, stdout2) => {
                    try {
                        var res2 = JSON.parse((stdout2 || "").trim())
                        if (res2.success && res2.text && res2.text.trim() !== "") {
                            root.isBusy = false
                            root.sendMessage(res2.text.trim())
                        } else if (res2.not_installed) {
                            root.isBusy = false
                            chatModel.append({
                                "role": "assistant",
                                "text": root.tr("Whisper Speech-to-Text is not installed. You can either use a native audio model (like lfm3-omni:2b) or install Whisper with: ./scripts/install-voice.sh", "Whisper Speech-to-Text no está instalado. Puedes usar un modelo con audio nativo (como lfm3-omni:2b) o instalar Whisper ejecutando: ./scripts/install-voice.sh"),
                                "toolInfo": ""
                            })
                        } else {
                            root.isBusy = false
                        }
                    } catch (e) {
                        root.isBusy = false
                    }
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

    function checkOllamaHealth(onResult) {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", Agent.buildModelsUrl(root.ollamaUrl))
        var key = (root.apiKey || "").trim()
        if (key !== "") {
            xhr.setRequestHeader("Authorization", "Bearer " + key)
        }
        xhr.timeout = onResult ? 6000 : 3000
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var names = Agent.parseModelsResponse(xhr.responseText)
                        root.ollamaConnected = true
                        root.availableModels = names

                        if (names.length > 0) {
                            var needsRebuild = (modelComboModel.count !== names.length)
                            if (!needsRebuild) {
                                for (var m = 0; m < names.length; m++) {
                                    if (modelComboModel.get(m).text !== names[m]) {
                                        needsRebuild = true
                                        break
                                    }
                                }
                            }
                            if (needsRebuild) {
                                modelComboModel.clear()
                                for (var j = 0; j < names.length; j++) {
                                    modelComboModel.append({"text": names[j]})
                                }
                            }
                            var activeEp = Agent.findEndpointById(root.endpoints, root.activeEndpointId)
                            var epDefModel = activeEp ? activeEp.defaultModel : ""
                            var picked = Agent.pickPreferredModel(names, epDefModel, root.currentModel)
                            if (picked !== root.currentModel) {
                                root.currentModel = picked
                            }
                        } else {
                            modelComboModel.clear()
                            root.currentModel = ""
                        }
                        if (onResult) onResult(true, 200, names.length)
                    } catch (e) {
                        console.error("Error parsing model list: " + e)
                        root.ollamaConnected = false
                        if (onResult) onResult(false, 200, "invalid_json")
                    }
                } else {
                    root.ollamaConnected = false
                    if (onResult) onResult(false, xhr.status, xhr.responseText || "")
                }
            }
        }
        xhr.send()
    }

    function clearChat() {
        root.requestGeneration++
        if (root.activeXhr !== null) {
            root.cancelRequested = true
            root.activeXhr.abort()
            root.activeXhr = null
        }
        root.isBusy = false
        root.busyStatus = "thinking"
        root.activeAssistantIndex = -1
        chatModel.clear()
        root.conversationHistory = []
        root.clearAttachment()
        chatModel.append({
            "role": "welcome",
            "text": root.getClearedMessage(),
            "toolInfo": ""
        })
    }

    function clearAttachment() {
        root.attachedFilePath = ""
        root.attachedFileName = ""
        root.attachedFileType = ""
        root.attachedFileText = ""
        root.capturedImageB64 = ""
    }

    function requestScreenshot() {
        root.isBusy = true
        root.runCli("python3 '" + root.toolsScriptPath + "' screenshot", (code, stdout) => {
            root.isBusy = false
            var b64 = (stdout || "").trim()
            if (b64.length > 100) {
                root.attachedFileType = "image"
                root.attachedFileName = ""
                root.attachedFilePath = "/tmp/bonsai_screenshot.png"
                root.attachedFileText = ""
                root.capturedImageB64 = b64
            }
        })
    }

    function requestAttachFile() {
        root.isPickingFile = true
        root.isBusy = true
        root.runCli("python3 '" + root.toolsScriptPath + "' pick_file", (code, stdout) => {
            root.isBusy = false
            root.isPickingFile = false
            if (code !== 0 || !stdout || stdout.trim() === "") return
            try {
                var res = JSON.parse(stdout.trim())
                if (res.cancelled) return
                if (res.success) {
                    if (res.type === "image") {
                        root.attachedFileType = "image"
                        root.attachedFileName = res.filename || "image"
                        root.attachedFilePath = res.path || ""
                        root.attachedFileText = ""
                        root.capturedImageB64 = res.base64_image || ""
                    } else {
                        root.attachedFileType = "document"
                        root.attachedFileName = res.filename || "file"
                        root.attachedFilePath = res.path || ""
                        root.attachedFileText = res.text || ""
                        root.capturedImageB64 = ""
                    }
                }
            } catch (e) {
                console.warn("Error parsing attached file: " + e)
            }
        })
    }

    function sendMessage(text, audioB64) {
        text = (text || "").trim()
        var hasDoc = (root.attachedFileType === "document" && root.attachedFileText !== "")
        var hasImg = (root.capturedImageB64 !== "")
        var hasAudio = !!(audioB64 && String(audioB64).trim() !== "")
        if (text === "" && !hasImg && !hasDoc && !hasAudio) {
            return
        }

        var userDisplayText = text
        if (hasDoc) {
            var docPrefix = "📄 **[" + root.attachedFileName + "]**\n"
            userDisplayText = docPrefix + (text !== "" ? text : root.tr("Please analyze or summarize this document.", "Por favor analiza o resume este documento."))
        } else if (hasImg && text === "") {
            userDisplayText = (root.attachedFileName !== "") ? ("🖼️ **[" + root.attachedFileName + "]**") : root.tr("[Screenshot attached]", "[Captura de pantalla adjunta]")
        } else if (hasAudio && text === "") {
            userDisplayText = root.tr("🎤 [Voice message]", "🎤 [Mensaje de voz]")
        }

        chatModel.append({
            "role": "user",
            "text": userDisplayText,
            "toolInfo": ""
        })

        var userMessageContent = text
        if (hasDoc) {
            userMessageContent = "Documento adjunto: '" + root.attachedFileName + "'\nRuta: " + root.attachedFilePath + "\n"
                                 + "--- Contenido del archivo ---\n"
                                 + root.attachedFileText + "\n"
                                 + "--- Fin del contenido ---\n\n"
                                 + (text !== "" ? text : "Por favor resume y analiza el contenido de este documento adjunto.")
        } else if (hasImg && text === "") {
            userMessageContent = "Por favor analiza la imagen adjunta."
        } else if (hasAudio && text === "") {
            userMessageContent = root.tr("Listen to the attached audio message and respond or execute the requested action.", "Escucha el mensaje de voz adjunto y responde o ejecuta la acción solicitada.")
        }

        var userMessageObj = {
            "role": "user",
            "content": userMessageContent
        }
        if (hasImg) {
            userMessageObj["images"] = [root.capturedImageB64]
        }
        if (hasAudio) {
            userMessageObj["audio"] = String(audioB64)
            userMessageObj["audioFormat"] = "wav"
        }
        root.conversationHistory.push(userMessageObj)
        root.clearAttachment()
        root.requestGeneration++
        var myGen = root.requestGeneration
        root.cancelRequested = false
        root.busyStatus = "thinking"
        root.isBusy = true

        var assistantIndex = chatModel.count
        root.activeAssistantIndex = assistantIndex
        chatModel.append({
            "role": "assistant",
            "text": "",
            "toolInfo": ""
        })

        var activeLang = (root.preferredLanguage && root.preferredLanguage !== "auto")
                         ? root.preferredLanguage
                         : root.detectLanguage(text)
        var customPrompt = (Plasmoid.configuration && Plasmoid.configuration.customSystemPrompt) ? Plasmoid.configuration.customSystemPrompt.trim() : ""
        var systemContent = Agent.buildSystemPrompt(activeLang, customPrompt)

        Agent.runChatLoop({
            "ollamaUrl": root.ollamaUrl,
            "apiKey": root.apiKey,
            "model": root.currentModel,
            "systemPrompt": systemContent,
            "lang": activeLang,
            "tools": root.toolDefinitions || [],
            "getHistory": function() {
                return root.conversationHistory
            },
            "appendHistory": function(msg) {
                root.conversationHistory.push(msg)
            },
            "isCancelled": function() {
                return root.cancelRequested || myGen !== root.requestGeneration
            },
            "onXhrCreated": function(xhr) {
                if (myGen === root.requestGeneration) {
                    root.activeXhr = xhr
                }
            },
            "onStatusChange": function(status) {
                if (myGen === root.requestGeneration) {
                    root.busyStatus = status
                }
            },
            "onToken": function(delta) {
                if (myGen !== root.requestGeneration) return
                var curText = chatModel.get(assistantIndex).text
                chatModel.setProperty(assistantIndex, "text", curText + delta)
                root.scrollToBottomRequested()
            },
            "executeTool": function(fnName, argsObj, lang, done) {
                var safeName = String(fnName || "").replace(/[^a-zA-Z0-9_]/g, "")
                var fnArgs = JSON.stringify(argsObj || {})
                var safeArgs = fnArgs.replace(/'/g, "'\\''")
                root.runCli(
                    "python3 '" + root.toolsScriptPath + "' --lang " + lang + " call " + safeName + " '" + safeArgs + "'",
                    done
                )
            },
            "onToolExecuted": function(fnName, resObj, pillMsg) {
                if (myGen !== root.requestGeneration) return
                var curTools = chatModel.get(assistantIndex).toolInfo
                var updated = curTools ? (curTools + " • " + pillMsg) : pillMsg
                chatModel.setProperty(assistantIndex, "toolInfo", updated)
                root.scrollToBottomRequested()
            },
            "onComplete": function(summary) {
                if (myGen !== root.requestGeneration) return
                root.isBusy = false
                root.busyStatus = "thinking"
                root.activeXhr = null
                root.activeAssistantIndex = -1

                // Si el modelo completó sin texto tras ejecutar herramientas, mostrar el resumen de la herramienta
                if (chatModel.get(assistantIndex).text === "" && summary.toolFallbackText) {
                    chatModel.setProperty(assistantIndex, "text", summary.toolFallbackText)
                    if (root.conversationHistory.length > 0 && root.conversationHistory[root.conversationHistory.length - 1].role === "assistant") {
                        root.conversationHistory[root.conversationHistory.length - 1].content = summary.toolFallbackText
                    }
                }
            },
            "onCancelled": function() {
                if (myGen !== root.requestGeneration && !root.cancelRequested) return
                root.finalizeCancelled(assistantIndex)
            },
            "onError": function(status) {
                if (myGen !== root.requestGeneration) return
                root.isBusy = false
                root.busyStatus = "thinking"
                root.activeXhr = null
                root.activeAssistantIndex = -1

                var errText = chatModel.get(assistantIndex).text
                if (errText === "") {
                    var errMsg = root.isLocalOllama
                        ? root.tr("Error communicating with Ollama (" + status + "). Make sure it is running.", "Error al comunicar con Ollama (" + status + "). Asegúrate de que se está ejecutando.")
                        : root.tr("Error communicating with AI server (" + status + "). Check the URL, model, and API key.", "Error al comunicar con el servidor IA (" + status + "). Revisa la URL, el modelo y la API key.")
                    chatModel.setProperty(assistantIndex, "text", errMsg)
                }
            }
        })
    }
}
