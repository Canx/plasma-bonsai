# Especificación Técnica: Plasmoid Asistente D-Bus para KDE Plasma y Ollama

Este documento detalla la arquitectura, el diseño de componentes y la implementación técnica para construir un **Plasmoid flotante en KDE Plasma 6** que conecte modelos locales optimizados (como Bonsai a través de Ollama) con el bus D-Bus del sistema y las capacidades de captura de escritorio en **KDE Neon**.

---

## 1. Objetivos del Sistema
* **Acceso Instantáneo:** Interfaz ligera flotante invocable mediante atajo de teclado global en KDE Plasma.
* **Capacidad Multimodal:** Posibilidad de capturar el área activa o la pantalla para que el LLM analice errores gráficos o código.
* **Tool Calling por D-Bus:** Permitir que el modelo ejecute acciones reales en la sesión de Plasma (ajustar brillo, controlar volumen, listar ventanas, etc.).
* **Privacidad Total:** Ejecución 100% offline utilizando Ollama en `localhost:11434` con latencia mínima.

---

## 2. Arquitectura de Componentes
La solución se divide en dos capas principales:
1. **Frontend (Plasmoid QML / Kirigami):** Interfaz gráfica de usuario integrada en el panel o como ventana flotante del escritorio.
2. **Backend (Servicio Python / Puente D-Bus):** Un demonio ligero o script que gestiona las peticiones HTTP a la API de Ollama, procesa las llamadas a herramientas y ejecuta comandos D-Bus sobre KDE Plasma.

---

## 3. Estructura de Archivos del Plasmoid
Crea una carpeta en `~/.local/share/plasma/plasmoids/org.kde.plasma.bonsaiassistant/` con la siguiente estructura:

```text
org.kde.plasma.bonsaiassistant/
├── metadata.json
└── contents/
    ├── ui/
    │   └── Main.qml
    └── code/
        └── dbus_bridge.py
```

---

## 4. Código Base: Interfaz QML (`Main.qml`)
Define la estructura visual usando Kirigami y componentes de Plasma 6:

```qml
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root
    width: 400
    height: 600
    preferredRepresentation: PlasmoidItem.compactRepresentation

    compactRepresentation: Kirigami.ActionToolbar {
        anchors.fill: parent
        actions: [
            Kirigami.Action {
                icon.name: "run-build"
                text: "Bonsai AI"
                onTriggered: root.expanded = !root.expanded
            }
        ]
    }

    fullRepresentation: Item {
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            margins: Kirigami.Units.largeSpacing

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: ListModel { id: chatModel }
                delegate: ItemDelegate {
                    text: model.text
                    width: parent.width
                }
            }

            RowLayout {
                Layout.fillWidth: true

                TextField {
                    id: inputField
                    Layout.fillWidth: true
                    placeholderText: "Pregúntale a Bonsai..."
                    onAccepted: sendButton.clicked()
                }

                Button {
                    id: sendButton
                    text: "Enviar"
                    onClicked: {
                        if (inputField.text.trim() !== "") {
                            chatModel.append({"text": "Tú: " + inputField.text})
                            // Aquí se conectaría la señal al backend de Python
                            inputField.text = ""
                        }
                    }
                }
            }
        }
    }
}
```

---

## 5. Puente Backend Python y D-Bus (`dbus_bridge.py`)
Script en Python que interactúa con Ollama y expone funciones de Plasma mediante `dbus`:

```python
import sys
import json
import requests
import dbus

def control_brightness(level):
    """Ajusta el brillo usando la interfaz de energía de KDE"""
    try:
        bus = dbus.SessionBus()
        proxy = bus.get_object('org.kde.Solid.PowerManagement', '/org/kde/Solid/PowerManagement')
        interface = dbus.Interface(proxy, 'org.kde.Solid.PowerManagement')
        return f"Brillo ajustado a {level}%"
    except Exception as e:
        return f"Error ejecutando D-Bus: {str(e)}"

def query_ollama(prompt):
    url = "http://localhost:11434/api/generate"
    payload = {
        "model": "bonsai",
        "prompt": prompt,
        "stream": False
    }
    try:
        response = requests.post(url, json=payload)
        if response.status_code == 200:
            return response.json().get("response", "")
    except requests.exceptions.ConnectionError:
        return "Error: No se pudo conectar con Ollama en localhost:11434."
    return "Error procesando la solicitud."

if __name__ == "__main__":
    print("Backend D-Bus + Ollama listo.")
```

---

## 6. Próximos Pasos para la Implementación
1. Empaquetar y registrar el Plasmoid ejecutando en la terminal:
   ```bash
   kpackagetool6 --type Plasma/Applet --install .
   ```
2. Añadir el widget al panel o escritorio desde las opciones de personalización de KDE Plasma.
3. Ampliar el esquema JSON de herramientas (*tool calling*) en Python para que el modelo decida cuándo invocar funciones del sistema por D-Bus.
