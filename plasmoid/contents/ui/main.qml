import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: root

    // En panel usa representación compacta, en escritorio usa representación completa
    Plasmoid.preferredRepresentation: (Plasmoid.formFactor === PlasmaCore.Types.Horizontal || Plasmoid.formFactor === PlasmaCore.Types.Vertical)
                                      ? Plasmoid.compactRepresentation
                                      : Plasmoid.fullRepresentation

    Plasmoid.icon: "preferences-system-network-sharing"
    Plasmoid.title: "Bonsai AI Assistant"

    property string daemonUrl: "http://127.0.0.1:11435"
    property bool isBusy: false
    property bool daemonConnected: false
    property string capturedImageB64: ""

    ListModel {
        id: chatModel
    }

    // Representación compacta (icono para paneles)
    Plasmoid.compactRepresentation: MouseArea {
        id: compactArea
        hoverEnabled: true
        onClicked: Plasmoid.expanded = !Plasmoid.expanded

        PlasmaCore.IconItem {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) - Kirigami.Units.smallSpacing
            height: width
            source: Plasmoid.icon
            active: compactArea.containsMouse
        }
    }

    // Representación completa (ventana flotante o widget en escritorio)
    Plasmoid.fullRepresentation: Item {
        id: fullRepItem
        Layout.minimumWidth: Kirigami.Units.gridUnit * 22
        Layout.minimumHeight: Kirigami.Units.gridUnit * 26
        Layout.preferredWidth: Kirigami.Units.gridUnit * 26
        Layout.preferredHeight: Kirigami.Units.gridUnit * 30

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            // Cabecera superior
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaCore.IconItem {
                    source: "preferences-system-network-sharing"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                }

                PlasmaComponents.Label {
                    text: "Bonsai Assistant"
                    font.bold: true
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: Kirigami.Units.gridUnit * 0.5
                    height: width
                    radius: width / 2
                    color: root.daemonConnected ? "#27ae60" : "#e74c3c"
                    Layout.alignment: Qt.AlignVCenter
                }

                PlasmaComponents.Label {
                    text: root.daemonConnected ? "Listo" : "Desconectado"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.7
                }

                PlasmaComponents.ToolButton {
                    icon.name: "edit-clear-all"
                    text: "Limpiar"
                    display: PlasmaComponents.AbstractButton.IconOnly
                    ToolTip.text: "Limpiar conversación"
                    ToolTip.visible: hovered
                    onClicked: root.clearChat()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: PlasmaCore.Theme.disabledTextColor
                opacity: 0.3
            }

            // Vista de mensajes
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

                    // Tarjeta de Bienvenida centrada
                    Rectangle {
                        id: welcomeCard
                        visible: bubbleDelegate.isWelcome
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 4
                        width: Math.min(bubbleDelegate.width - 24, 460)
                        height: welcomeCol.implicitHeight + 18
                        radius: 8
                        color: PlasmaCore.Theme.backgroundColor
                        border.color: "#27ae60"
                        border.width: 1

                        ColumnLayout {
                            id: welcomeCol
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6

                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 8

                                PlasmaCore.IconItem {
                                    source: "preferences-system-network-sharing"
                                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                }

                                PlasmaComponents.Label {
                                    text: "Bonsai Assistant"
                                    font.bold: true
                                    color: "#27ae60"
                                }
                            }

                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: model.text
                                wrapMode: Text.Wrap
                                horizontalAlignment: Text.AlignHCenter
                                textFormat: Text.PlainText
                                opacity: 0.9
                                color: PlasmaCore.Theme.textColor
                            }
                        }
                    }

                    // Burbujas de conversación normales
                    Rectangle {
                        id: bubbleBox
                        visible: !bubbleDelegate.isWelcome && (model.text !== "" || (model.toolInfo && model.toolInfo !== ""))
                        anchors.top: parent.top
                        anchors.topMargin: 4
                        anchors.left: bubbleDelegate.isUser ? undefined : parent.left
                        anchors.right: bubbleDelegate.isUser ? parent.right : undefined
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10

                        width: Math.min(bubbleDelegate.width * 0.90, 500)
                        height: innerCol.implicitHeight + 18
                        radius: 8
                        color: bubbleDelegate.isUser 
                               ? PlasmaCore.Theme.highlightColor 
                               : PlasmaCore.Theme.backgroundColor
                        border.color: PlasmaCore.Theme.disabledTextColor
                        border.width: 1

                        Column {
                            id: innerCol
                            anchors.fill: parent
                            anchors.margins: 9
                            spacing: 4

                            PlasmaComponents.Label {
                                text: bubbleDelegate.isUser ? "Tú" : "Bonsai"
                                font.bold: true
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                color: bubbleDelegate.isUser ? PlasmaCore.Theme.highlightedTextColor : "#27ae60"
                            }

                            PlasmaComponents.Label {
                                id: msgLabel
                                width: parent.width
                                text: model.text
                                wrapMode: Text.Wrap
                                textFormat: Text.PlainText
                                color: bubbleDelegate.isUser 
                                       ? PlasmaCore.Theme.highlightedTextColor 
                                       : PlasmaCore.Theme.textColor
                            }

                            Rectangle {
                                visible: model.toolInfo && model.toolInfo !== ""
                                width: toolLabel.implicitWidth + 12
                                height: toolLabel.implicitHeight + 4
                                radius: 4
                                color: PlasmaCore.Theme.backgroundColor
                                border.color: PlasmaCore.Theme.highlightColor
                                border.width: 1

                                PlasmaComponents.Label {
                                    id: toolLabel
                                    anchors.centerIn: parent
                                    text: "🔧 " + (model.toolInfo || "")
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                                    opacity: 0.9
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
                    color: PlasmaCore.Theme.highlightColor
                    radius: 3
                    implicitWidth: imgBadge.implicitWidth + 8
                    implicitHeight: imgBadge.implicitHeight + 4

                    PlasmaComponents.Label {
                        id: imgBadge
                        anchors.centerIn: parent
                        text: "📸 Captura de pantalla lista para analizar"
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        color: PlasmaCore.Theme.highlightedTextColor
                    }
                }

                PlasmaComponents.ToolButton {
                    icon.name: "dialog-close"
                    display: PlasmaComponents.AbstractButton.IconOnly
                    onClicked: root.capturedImageB64 = ""
                }
            }

            // Indicador de actividad
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
                    text: "Bonsai está procesando..."
                    font.italic: true
                    opacity: 0.7
                }
            }

            // Caja inferior de entrada
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.ToolButton {
                    icon.name: "camera-photo"
                    ToolTip.text: "Capturar pantalla para analizar"
                    ToolTip.visible: hovered
                    enabled: !root.isBusy
                    onClicked: root.requestScreenshot()
                }

                PlasmaComponents.TextField {
                    id: promptInput
                    Layout.fillWidth: true
                    placeholderText: "Pregunta o pide una acción a Bonsai..."
                    enabled: !root.isBusy
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
                    text: "Enviar"
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
        }
    }

    // Temporizador para comprobar la conexión con el demonio
    Timer {
        id: healthCheckTimer
        interval: 3000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.checkDaemonHealth()
    }

    Component.onCompleted: {
        chatModel.append({
            "role": "welcome",
            "text": "¡Hola! Soy Bonsai, tu asistente local en KDE Plasma. Puedo ayudarte con tareas, responder preguntas o controlar funciones de tu escritorio (brillo, volumen, capturas, notificaciones).",
            "toolInfo": ""
        })
    }

    // Funciones hacia el demonio en 127.0.0.1:11435
    function checkDaemonHealth() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", root.daemonUrl + "/health")
        xhr.timeout = 2000
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                root.daemonConnected = (xhr.status === 200)
            }
        }
        xhr.send()
    }

    function clearChat() {
        chatModel.clear()
        chatModel.append({
            "role": "welcome",
            "text": "Conversación reiniciada. ¿En qué te puedo ayudar ahora?",
            "toolInfo": ""
        })
        var xhr = new XMLHttpRequest()
        xhr.open("POST", root.daemonUrl + "/clear")
        xhr.send()
    }

    function requestScreenshot() {
        root.isBusy = true
        var xhr = new XMLHttpRequest()
        xhr.open("POST", root.daemonUrl + "/screenshot")
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                root.isBusy = false
                if (xhr.status === 200) {
                    try {
                        var res = JSON.parse(xhr.responseText)
                        if (res.success && res.base64_image) {
                            root.capturedImageB64 = res.base64_image
                        }
                    } catch (e) {
                        console.error("Error al procesar captura: " + e)
                    }
                }
            }
        }
        xhr.send(JSON.stringify({"mode": "fullscreen"}))
    }

    function sendMessage(text) {
        text = (text || "").trim()
        if (text === "" && root.capturedImageB64 === "") {
            return
        }

        chatModel.append({
            "role": "user",
            "text": text !== "" ? text : "[Captura de pantalla enviada]",
            "toolInfo": ""
        })

        var imgToSend = root.capturedImageB64
        root.capturedImageB64 = ""
        root.isBusy = true

        // Creamos la burbuja del asistente para recibir el stream
        var assistantIndex = chatModel.count
        chatModel.append({
            "role": "assistant",
            "text": "",
            "toolInfo": ""
        })

        var xhr = new XMLHttpRequest()
        xhr.open("POST", root.daemonUrl + "/chat_stream")
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 240000

        var lastProcessed = 0

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
                    if (line.indexOf("data: ") === 0) {
                        try {
                            var data = JSON.parse(line.substring(6))
                            if (data.type === "token" && data.content) {
                                var curText = chatModel.get(assistantIndex).text
                                chatModel.setProperty(assistantIndex, "text", curText + data.content)
                                chatListView.positionViewAtEnd()
                            } else if (data.type === "tool") {
                                var msg = data.message || data.name || "Herramienta ejecutada"
                                var curTools = chatModel.get(assistantIndex).toolInfo
                                var updated = curTools ? (curTools + ", " + msg) : msg
                                chatModel.setProperty(assistantIndex, "toolInfo", updated)
                                chatListView.positionViewAtEnd()
                            } else if (data.type === "done") {
                                root.isBusy = false
                            }
                        } catch (e) {}
                    }
                }
            }

            if (xhr.readyState === 4) {
                root.isBusy = false
                if (xhr.status !== 200) {
                    var finalCheck = chatModel.get(assistantIndex).text
                    if (finalCheck === "") {
                        chatModel.setProperty(assistantIndex, "text", "Error al comunicarse con el demonio de Bonsai.")
                    }
                }
            }
        }

        xhr.send(JSON.stringify({
            "message": text,
            "image_b64": imgToSend
        }))
    }
}
