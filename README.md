# Plasma Bonsai Assistant 🌿

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![KDE Plasma](https://img.shields.io/badge/KDE%20Plasma-6-blue)](https://kde.org/plasma-desktop/)
[![Ollama](https://img.shields.io/badge/Ollama-Local%20AI-orange)](https://ollama.com/)

**Plasma Bonsai Assistant** es un widget (*Plasmoid*) nativo para el entorno de escritorio **KDE Plasma 6** que integra modelos de lenguaje locales ejecutados en **Ollama** (como `bonsai-2`, `qwen2.5`, `llama3.1`, `gemma4`) directamente en tu panel o escritorio, con capacidades de **visión multimodal** y **control del sistema**.

Funciona **100% en espacio de usuario**: no requiere demonios permanentes en segundo plano, puertos intermedios abiertos ni permisos de administrador.

---

## ✨ Características Principales

* 🔒 **100% Privado y Local:** Se conecta directamente a tu servidor Ollama local en `http://localhost:11434`. Cero telemetría externa.
* ⚡ **Arquitectura Standalone (Sin demonio residente):** Funciona directamente desde el Plasmoid de KDE. No consume memoria en segundo plano cuando no se está utilizando.
* 🎨 **UI Nativa en Qt6 / Kirigami:**
  * Respuestas en tiempo real con **streaming de tokens**.
  * Renderizado enriquecido de **Markdown** (negritas, cursivas, listas, código).
  * Botón para **copiar respuestas al portapapeles** con un solo clic.
  * Selector desplegable para cambiar de modelo al vuelo.
* 📸 **Visión Multimodal del Escritorio:** Captura instantánea de pantalla con Spectacle para analizar ventanas, código o errores visuales con modelos con soporte de visión.
* 🛠️ **Acciones del Sistema (Tool Calling):**
  * **Brillo de pantalla:** Consulta y ajuste porcentual a través de `org.kde.Solid.PowerManagement`.
  * **Audio del sistema:** Consulta, ajuste de volumen y silencio mediante PulseAudio / PipeWire.
  * **Fondo de pantalla:** Cambio dinámico del wallpaper de Plasma según temática o archivo.
  * **Abrir aplicaciones:** Lanzamiento de apps (`terminal/konsole`, `kate`, `firefox`, `dolphin`, etc.).
  * **Gestión de ventanas:** Vista general de ventanas (*overview*), mostrar escritorio y mosaico 50/50.
  * **Temporizadores y alarmas:** Avisos de cuenta atrás con sonido y notificación nativa (ej: *"Pon un temporizador de 10 minutos para la pizza"*).
  * **Seguridad y avisos:** Bloqueo inmediato de sesión y notificaciones nativas del escritorio.

---

## 🏛️ Arquitectura del Sistema

```mermaid
flowchart TD
    User["👤 Usuario (Panel / Atajo de teclado)"] --> QML["🖥️ Plasmoid Nativo Qt6 (KDE Plasma 6)"]
    QML -->|Streaming HTTP Directo| Ollama["🦙 Ollama Server (localhost:11434)"]
    QML -.->|Herramientas bajo demanda| Tools["⚙️ Runner de Acciones del Sistema"]
    
    subgraph Tools["Acciones del Sistema"]
        Solid["🔆 Solid PowerManagement (Brillo)"]
        Audio["🔊 Audio PipeWire / PulseAudio (Volumen)"]
        Spectacle["📸 Spectacle (Captura de pantalla)"]
        PlasmaShell["🖼️ PlasmaShell (Fondo de pantalla)"]
        KWin["🪟 KWin (Ventanas y Atajos)"]
    end
```

---

## 📁 Estructura del Repositorio

```text
plasma-bonsai/
├── plasmoid/                       # Paquete de la extensión KDE Plasma 6
│   ├── metadata.json               # Metadatos para Plasma 6 (X-Plasma-API-Minimum-Version: 6.0)
│   └── contents/
│       ├── ui/
│       │   └── main.qml            # Interfaz gráfica en PlasmoidItem / Kirigami
│       └── code/
│           └── tools.py            # Runner de herramientas del sistema (Python estándar + D-Bus)
├── scripts/
│   ├── install.sh                  # Instalación local con kpackagetool6
│   └── run-dev.sh                  # Entorno de pruebas aislado con plasmawindowed
├── README.md                       # Documentación principal
└── LICENSE                         # Licencia MIT
```

---

## 🚀 Requisitos Previos

1. **KDE Plasma 6**
2. **Python 3** (incluido por defecto en cualquier distribución Linux moderna)
3. **Ollama:** Ejecutándose en `localhost:11434`
   * Si aún no tienes Ollama instalado:
     ```bash
     curl -fsSL https://ollama.ai/install.sh | sh
     ```
   * Puedes descargar cualquier modelo con soporte de chat o visión:
     ```bash
     ollama pull bonsai-2:latest
     # Alternativas recomendadas:
     ollama pull qwen2.5:7b
     ollama pull llama3.1:8b
     ```

---

## 📦 Instalación

### Desde el repositorio local
Ejecuta el script de instalación:

```bash
cd plasma-bonsai
./scripts/install.sh
```

El script registra el plasmoid en tu usuario con `kpackagetool6` (`~/.local/share/plasma/plasmoids/org.kde.plasma.bonsai`).

### Añadir el widget al escritorio
1. Haz clic derecho en tu panel de KDE o en el escritorio.
2. Selecciona **Añadir elementos gráficos…** (o presiona `Meta + W`).
3. Busca **Plasma Bonsai Assistant** y arrástralo a tu barra de tareas.

---

## 🧪 Pruebas en Modo Desarrollo

Para probar el widget en una ventana flotante de desarrollo sin alterar tus paneles:

```bash
./scripts/run-dev.sh
```

---

## 🛠️ Ejemplos de Interacción

* **Ajustar brillo:** *"Baja el brillo de la pantalla al 30%"*
* **Controlar volumen:** *"Pon el volumen al 50%"* o *"Silencia el audio"*
* **Cambiar fondo:** *"Pon un fondo de pantalla oscuro"* o *"Cambia el fondo a uno de montaña"*
* **Abrir aplicaciones:** *"Abre la terminal"*, *"Abre Kate"* o *"Abre el navegador"*
* **Gestión de ventanas:** *"Muestra el escritorio"* o *"Pon la ventana en mosaico"*
* **Temporizadores y alarmas:** *"Pon un temporizador de 10 minutos para la pizza"*, *"¿Cuánto queda de temporizador?"* o *"Cancela la alarma"*
* **Analizar la pantalla:** Pulsa el icono de la cámara 📸 y escribe *"¿Qué error se ve en esta pantalla?"*
* **Bloquear escritorio:** *"Bloquea la sesión"*

---

## 🗺️ Hoja de Ruta y Próximas Funcionalidades

Consulta el archivo [TODO.md](TODO.md) para ver la lista detallada de tareas planificadas, destacando:
* 🎙️ **Interacción por voz (Speech-to-Text local con Whisper y síntesis de voz TTS)**
* 🎵 **Control multimedia universal (Spotify, VLC, YouTube vía MPRIS2)**
* 🌓 **Conmutador de tema oscuro / claro al vuelo**
* 🔋 **Estado de batería y recursos del sistema (RAM / CPU)**
* 📋 **Integración con el historial del portapapeles de KDE (Klipper)**
* 🔎 **Búsqueda rápida de archivos en local (Baloo / fd)**

---

## 🔒 Seguridad y Privacidad

* **100% Offline y Privado:** Todo el procesamiento del modelo de lenguaje se realiza en tu equipo. Ninguna información, texto ni imagen sale a internet.
* **Sin demonios residentes ni puertos adicionales:** El widget no abre puertos de red ni deja procesos permanentemente en ejecución.
* **Privilegios estándar:** No se requieren permisos de administrador (`root` o `sudo`).

---

## 📄 Licencia

Distribuido bajo la licencia MIT. Consulta `LICENSE` para más información.
