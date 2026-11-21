# KDE Store Listing Guide: Plasma Bonsai Assistant 🌿

Ficha lista para copiar y pegar al publicar en **[store.kde.org](https://store.kde.org)**.

---

## 📌 Datos Básicos del Formulario

* **Product Name:** `Plasma Bonsai Assistant`
* **Category:** `Plasma 6 Applets` *(⚠️ IMPORTANTE: Seleccionar categoría Plasma 6, no Plasma 5)*
* **Version:** `1.2.1`
* **License:** `MIT`
* **Homepage / Source Code:** `https://github.com/Canx/plasma-bonsai`
* **Tags:** `ai`, `ollama`, `litellm`, `openai`, `assistant`, `plasma 6`, `local ai`, `offline`, `voice`, `qml`

---

## 📝 Resumen Corto (Short Description)
> Smart, private AI assistant for KDE Plasma 6 with multi-endpoint support (Ollama, LiteLLM, vLLM, OpenAI-compatible), multi-step tool calling, vision, and voice. No resident background daemon required.

---

## 🆕 Changelog v1.2.1 (para el campo "Changelog" de KDE Store)

```text
Unified OpenAI-compatible API (/v1/models & /v1/chat/completions SSE): works seamlessly with local Ollama as well as remote LiteLLM, vLLM, OpenRouter, LM Studio, and OpenAI servers with optional Bearer API Key authentication.
Added Multi-Endpoint support: configure multiple AI servers (e.g. local Ollama + remote LiteLLM), each with its own auto-detected Default Model dropdown, plus a compact clickable header badge to switch endpoints and models in 1 click.
Added Zero-Config first-run onboarding: automatic Ollama detection, 1-click terminal installer if missing, and built-in starter model downloader (bonsai-2:2b, lfm3-omni:2b, qwen3:4b) with live progress bar.
Added native audio input (input_audio): sends recorded voice directly to audio/omni models (such as lfm3-omni:2b or Gemini via LiteLLM) without requiring Whisper, while keeping Whisper STT for text-only models.
Added live connection test feedback in Settings showing detected model count or specific HTTP/network errors.
```

---

## 📖 Descripción Completa (Texto Limpio Universal para la Tienda)

```text
🌿 Plasma Bonsai Assistant

A native, lightweight, and privacy-first AI assistant widget for KDE Plasma 6. Connect to your local Ollama instance or any remote OpenAI-compatible server (LiteLLM, vLLM, OpenRouter, LM Studio, OpenAI) for fast streaming chat, desktop vision, voice input, and deep KDE system integration—right from your panel or desktop.

━━━━━━━━━━━━━━━━━━━━━
✨ KEY FEATURES
━━━━━━━━━━━━━━━━━━━━━

🔌 Local Ollama & Remote OpenAI-Compatible Endpoints:
Works out of the box with local Ollama (http://127.0.0.1:11434) and remote LiteLLM, vLLM, OpenRouter, or OpenAI servers with optional API Key support. Configure multiple endpoints, each with its own default model, and switch between them in 1 click from the compact header badge.

🌱 Zero-Config Onboarding:
Automatically detects if Ollama is installed or running, offers 1-click installation/startup, and lets you download starter models (bonsai-2:2b, lfm3-omni:2b, qwen3:4b) with a built-in progress bar—or jump straight to configuring a remote server.

⚡ Standalone & Daemonless:
Runs purely in user space. No heavy background daemon consuming RAM 24/7.

🎨 Native Qt6 & Kirigami UI:
Real-time SSE token streaming, rich text rendering, quick copy button, pinned window mode, and instant request cancellation (Stop / Esc).

📸 Multimodal Vision & Native Voice:
• Integrated screenshot capture (Spectacle) and file/PDF attachment.
• Native audio input (input_audio) for omni/audio models (like lfm3-omni:2b or Gemini via LiteLLM), plus optional local Whisper STT for text-only models.

🛠️ Agentic System Control & Actions (Multi-step Tool Calling):
• Chained Tool Loop: Bonsai inspects tool results and chains multiple actions automatically (e.g. search a file → read it → summarize it)
• Screen Brightness: Adjust or set exact percentage ("Set brightness to 60%")
• Audio & Media (MPRIS2): Adjust volume, mute/unmute, and control Spotify, VLC, Elisa, or browser playback
• Clipboard (Klipper): Read, summarize, or update clipboard and mouse selection
• Wallpaper: Change Plasma wallpaper on demand
• Application Launcher: Open terminal, browser, Dolphin, text editor, etc.
• Window Management: Toggle desktop view, overview, or 50/50 window tiling
• File Operations: Safe folder creation in $HOME, PDF/code/text reading, and fast document search with native KDE Baloo ("Find invoice and read it")
• Timers: Native KDE notifications with timers ("Set a 10 min timer")
• Security: Lock desktop session instantly

⚙️ Integrated Settings:
Manage multiple endpoints, test connections with live feedback, pick default models from auto-detected dropdowns, set preferred language (Auto / English / Spanish), and customize the System Prompt directly in the widget.

━━━━━━━━━━━━━━━━━━━━━
🚀 REQUIREMENTS
━━━━━━━━━━━━━━━━━━━━━

1. KDE Plasma 6
2. Python 3
3. Either:
   • Local Ollama (can be installed and set up directly from the widget), OR
   • Any remote OpenAI-compatible endpoint (LiteLLM, vLLM, OpenRouter, etc.)

━━━━━━━━━━━━━━━━━━━━━
💖 SUPPORT & LINKS
━━━━━━━━━━━━━━━━━━━━━

Plasma Bonsai is 100% free and open-source.
• Sponsor on GitHub: https://github.com/sponsors/Canx
• Source Code & Issues: https://github.com/Canx/plasma-bonsai
```

---

## 🖼️ Lista de Verificación de Archivos (Files & Media)
1. **Archivo principal (.plasmoid):** Subir `plasma-bonsai.plasmoid` (generado con `./scripts/package.sh`).
2. **Icono / Logo:** `assets/plasma-bonsai-512.png` o `assets/plasma-bonsai.svg`.
3. **Capturas de pantalla:** 2 o 3 imágenes mostrando la interfaz en el panel, el selector compacto de endpoint/modelo y alguna acción ejecutada.
