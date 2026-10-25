import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: root

    Plasmoid.preferredRepresentation: Plasmoid.compactRepresentation

    Plasmoid.icon: "preferences-system-network-sharing"
    Plasmoid.title: "Bonsai AI Assistant"

    property string daemonUrl: "http://127.0.0.1:11435"
    property bool isBusy: false
    property bool daemonConnected: false
    property string capturedImageB64: ""

    ListModel {
        id: chatModel
    }

    // Representación compacta (icono en la barra de tareas)
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

    // Representación completa (ventana flotante/desplegable)
    Plasmoid.fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 22
        Layout.minimumHeight: Kirigami.Units.gridUnit * 28
        Layout.preferredWidth: Kirigami.Units.gridUnit * 26
        Layout.preferredHeight: Kirigami.Units.gridUnit * 32

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
                    color: root.daemonConnected ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.neutralTextColor
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
                color: Kirigami.Theme.separatorColor
                opacity: 0.5
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

                delegate: ColumnLayout {
                    width: chatListView.width - Kirigami.Units.gridUnit
                    spacing: Kirigami.Units.smallSpacing * 0.5

                    // Indicador de remitente
                    PlasmaComponents.Label {
                        text: model.role === "user" ? "Tú" : "Bonsai"
                        font.bold: true
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        color: model.role === "user" ? Kirigami.Theme.highlightColor : Kirigami.Theme.positiveTextColor
                        Layout.alignment: model.role === "user" ? Qt.AlignRight : Qt.AlignLeft
                    }

                    // Burbuja de contenido
                    Rectangle {
                        Layout.fillWidth: false
                        Layout.maximumWidth: parent.width * 0.92
                        Layout.alignment: model.role === "user" ? Qt.AlignRight : Qt.AlignLeft
                        implicitWidth: messageText.implicitWidth + Kirigami.Units.largeSpacing
                        implicitHeight: messageText.implicitHeight + Kirigami.Units.smallSpacing * 2
                        radius: Kirigami.Units.smallSpacing
                        color: model.role === "user" 
                               ? Kirigami.Theme.highlightColor 
                               : Kirigami.Theme.backgroundColor
                        border.color: Kirigami.Theme.separatorColor
                        border.width: 1

                        PlasmaComponents.Label {
                            id: messageText
                            anchors.fill: parent
                            anchors.margins: Kirigami.Units.smallSpacing
                            text: model.text
                            wrapMode: Text.Wrap
                            textFormat: Text.PlainText
                            color: model.role === "user" 
                                   ? Kirigami.Theme.highlightedTextColor 
                                   : Kirigami.Theme.textColor
                        }
                    }

                    // Distintivo de herramientas ejecutadas
                    Rectangle {
                        visible: model.toolInfo && model.toolInfo !== ""
                        Layout.alignment: Qt.AlignLeft
                        implicitWidth: toolLabel.implicitWidth + Kirigami.Units.smallSpacing * 2
                        implicitHeight: toolLabel.implicitHeight + 4
                        radius: 4
                        color: Kirigami.Theme.neutralBackgroundColor
                        border.color: Kirigami.Theme.separatorColor
                        border.width: 1

                        PlasmaComponents.Label {
                            id: toolLabel
                            anchors.centerIn: parent
                            text: "🔧 " + (model.toolInfo || "")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                            opacity: 0.85
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
                        text: "📸 Captura de pantalla lista para analizar"
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
                    id: promptField
                    Layout.fillWidth: true
                    placeholderText: "Pregunta o pide una acción a Bonsai..."
                    enabled: !root.isBusy
                    onAccepted: root.sendMessage()
                }

                PlasmaComponents.Button {
                    id: sendBtn
                    icon.name: "document-send"
                    text: "Enviar"
                    enabled: !root.isBusy && promptField.text.trim() !== ""
                    onClicked: root.sendMessage()
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
            "role": "assistant",
            "text": "¡Hola Rubén! Soy Bonsai, tu asistente local en KDE Plasma. Puedo ayudarte con tareas, responder preguntas o controlar funciones de tu escritorio (brillo, volumen, capturas, notificaciones).",
            "toolInfo": ""
        })
    }

    // Funciones de red hacia el demonio en 127.0.0.1:11435
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
            "role": "assistant",
            "text": "Conversación reiniciada. ¿En qué te ayudo ahora?",
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
                        var res = jsonParse(xhr.responseText)
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

    function sendMessage() {
        var text = promptField.text.trim()
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
        promptField.text = ""
        root.isBusy = true

        var xhr = new XMLHttpRequest()
        xhr.open("POST", root.daemonUrl + "/chat")
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 180000

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                root.isBusy = false
                if (xhr.status === 200) {
                    try {
                        var res = jsonParse(xhr.responseText)
                        var toolsText = ""
                        if (res.tools_executed && res.tools_executed.length > 0) {
                            var tNames = []
                            for (var i = 0; i < res.tools_executed.length; i++) {
                                var t = res.tools_executed[i]
                                var msg = (t.result && t.result.message) ? t.result.message : t.name
                                tNames.push(msg)
                            }
                            toolsText = tNames.join(", ")
                        }

                        chatModel.append({
                            "role": "assistant",
                            "text": res.reply || "(Sin respuesta de texto)",
                            "toolInfo": toolsText
                        })
                    } catch (e) {
                        chatModel.append({
                            "role": "assistant",
                            "text": "Error al procesar la respuesta del asistente.",
                            "toolInfo": ""
                        })
                    }
                } else {
                    var errText = "Error al comunicarse con el demonio de Bonsai."
                    try {
                        var errJson = jsonParse(xhr.responseText)
                        if (errJson.error) {
                            errText = errJson.error
                        }
                    } catch (e) {}
                    chatModel.append({
                        "role": "assistant",
                        "text": errText,
                        "toolInfo": ""
                    })
                }
            }
        }

        xhr.send(JSON.stringify({
            "message": text,
            "image_b64": imgToSend
        }))
    }

    function jsonParse(str) {
        return JSON.parse(str)
    }
}
