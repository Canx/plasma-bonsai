# KDE Store Listing Guide: Plasma Bonsai Assistant 🌿

Ficha lista para copiar y pegar al publicar en **[store.kde.org](https://store.kde.org)**.

---

## 📌 Datos Básicos del Formulario

* **Product Name:** `Plasma Bonsai Assistant`
* **Category:** `Plasma 6 Applets` *(⚠️ IMPORTANTE: Seleccionar categoría Plasma 6, no Plasma 5)*
* **Version:** `1.0.0`
* **License:** `MIT`
* **Homepage / Source Code:** `https://github.com/Canx/plasma-bonsai`
* **Tags:** `ai`, `ollama`, `assistant`, `plasma 6`, `local ai`, `offline`, `voice`, `chatgpt alternative`, `qml`

---

## 📝 Resumen Corto (Short Description)
> Smart, private, local AI assistant for KDE Plasma 6 integrated directly with Ollama and system controls. No resident background daemon required.

---

## 📖 Descripción Completa (Full Description - Markdown / BBCode)

```markdown
### 🌿 Plasma Bonsai Assistant
A native, lightweight, and completely private AI assistant widget for **KDE Plasma 6**. Connects directly to your local **Ollama** instance to provide fast streaming chat, desktop multimodal vision, voice interactions, and deep KDE system integration—right from your panel or desktop.

---

### ✨ Key Features

* 🔒 **100% Local & Private:** Connects directly to Ollama at `http://localhost:11434`. Zero tracking, zero telemetry, no external API keys required.
* ⚡ **Standalone / Daemonless Architecture:** Runs 100% in user space. No heavy background daemon running 24/7 consuming RAM.
* 🎨 **Native Qt6 & Kirigami UI:**
  * Real-time token streaming with animated typing indicator.
  * Rich Markdown rendering (headers, bold, italics, formatted lists, code blocks).
  * One-click button to copy answers directly to clipboard.
  * Model selector dropdown to switch between Ollama models on the fly.
* 📸 **Multimodal Desktop Vision:** Integrated screenshot tool via Spectacle to analyze windows, code errors, or graphics using vision models (e.g., `llava`, `bonsai-2`, `qwen2.5-vl`).
* 🛠️ **System Control & Actions (Natural Language Tool Calling):**
  * **Screen Brightness:** Ask to raise, lower, or set exact brightness percentage (via `Solid PowerManagement`).
  * **Audio Control:** Volume adjustment and mute/unmute via PipeWire / PulseAudio.
  * **Wallpaper:** Change Plasma wallpaper on demand based on theme or filename.
  * **Launch Apps:** Open terminal, browser, text editor, Dolphin, etc.
  * **Window Management:** Toggle desktop view, overview, or 50/50 window tiling.
  * **File System Operations:** Safe folder creation inside user home directory, plus fast file/document search with KDE Baloo and automatic document opening with default apps (e.g., *"Find the document invoice and open it"*).
  * **Timers & Alarms:** Set timers with native notifications and alarm sounds (e.g., *"Set a 10 minute pizza timer"*).
  * **Security:** Lock current desktop session immediately.
* 🎙️ **Local Voice Input & Speech (Optional):** Push-to-talk support with Whisper and Piper TTS offline.

---

### 🚀 Requirements

1. **KDE Plasma 6**
2. **Python 3** (included in any modern Linux distribution)
3. **Ollama:** Running locally on `http://localhost:11434`
   * To install Ollama: `curl -fsSL https://ollama.ai/install.sh | sh`
   * Recommended models:
     ```bash
     ollama pull qwen2.5:7b
     ollama pull llama3.1:8b
     ollama pull bonsai-2:latest
     ```

---

### 📦 Installation

#### Option 1: Via Plasma Store (Recommended)
Click **Install** right here or search for **Plasma Bonsai Assistant** in:
*Right-click Desktop/Panel -> Add Widgets... -> Get New Widgets...*

#### Option 2: Manual Installation via Terminal
Download `plasma-bonsai.plasmoid` and run:
```bash
kpackagetool6 --type Plasma/Applet --install plasma-bonsai.plasmoid
```

---

### 💖 Support the Project
Plasma Bonsai is 100% free, private, and open-source. If you find it useful, consider supporting its development:
* 💖 [Sponsor on GitHub](https://github.com/sponsors/Canx)
* ☕ [Buy me a coffee on Ko-fi](https://ko-fi.com/canx)

---

### 📄 License & Source Code
* Open Source under the **MIT License**.
* Contributions and issues are welcome on [GitHub](https://github.com/Canx/plasma-bonsai).
```

---

## 🖼️ Lista de Verificación de Archivos (Files & Media)
1. **Archivo principal (.plasmoid):** Subir `plasma-bonsai.plasmoid`.
2. **Icono / Logo:** Imagen cuadrada representativa (PNG o SVG).
3. **Capturas de pantalla:** 2 o 3 imágenes mostrando la interfaz en el panel y alguna acción ejecutada.
