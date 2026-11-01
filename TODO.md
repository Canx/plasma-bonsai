# 📋 Hoja de Ruta y Tareas Pendientes (TODO)

Lista de nuevas herramientas, integraciones y características planificadas para **Plasma Bonsai Assistant**.

---

## 🌟 Característica Estrella: Interacción por Voz (STT & TTS) 🎙️🔊

Poder hablar directamente con Bonsai y que responda con voz natural, **100% en local y offline**.

- [ ] **Botón Push-to-Talk 🎙️ en la UI:**
  - Añadir botón de micrófono en la barra inferior (junto a la cámara 📸).
  - Indicador visual mientras esté escuchando (ondas o pulsación roja).
- [ ] **Captura de audio nativa con PipeWire:**
  - Grabación directa desde el micrófono por defecto con `pw-record` a formato WAV en `/tmp/bonsai_audio.wav`.
- [ ] **Transcripción Local (Speech-to-Text):**
  - Integración con **Whisper.cpp** o **Sherpa-ONNX / Faster-Whisper** (modelo `tiny` o `base` en español, ~75MB).
  - Inserción automática del texto reconocido en la caja de prompt y envío inmediato.
- [ ] **Respuesta por Voz Opcional (Text-to-Speech):**
  - Soporte para **Piper TTS** (voces neuronales ultrarrápidas y offline en español como `es_ES-davefx-medium`).
  - Botón en la burbuja del asistente para escuchar la respuesta o modo de conversación continuo manos libres.

---

## 🛠️ Nuevas Herramientas del Sistema (Tool Calling)

### 1. Control Multimedia Universal (MPRIS2) 🎵
- [ ] **Soporte para Spotify, VLC, YouTube/Navegadores, Elisa, etc.:**
  - **Consultar reproducción:** *"¿Qué canción está sonando?"* (título, artista, álbum).
  - **Control de reproducción:** *"Pausa la música"*, *"Reanuda la canción"*, *"Siguiente pista"*, *"Canción anterior"*.
  - **Implementación:** Protocolo D-Bus estándar `org.mpris.MediaPlayer2` o utilidad `playerctl`.

### 2. Conmutador de Modo Oscuro / Claro 🌓
- [ ] **Cambio de tema al vuelo:**
  - *"Pon el modo oscuro"* o *"Activa el tema claro"*.
  - **Implementación:** Comando nativo de KDE `plasma-apply-colorscheme BreezeDark` / `BreezeLight`.

### 3. Estado del Hardware y Batería 🔋
- [ ] **Información de energía:**
  - *"¿Cuánta batería le queda al portátil?"*, *"¿Está cargando?"*.
  - **Implementación:** Consulta a D-Bus `org.freedesktop.UPower` o `/sys/class/power_supply`.
- [ ] **Recursos del sistema:**
  - *"¿Cuánta RAM libre tengo?"*, *"¿Qué uso de CPU hay?"*.
  - **Implementación:** `free -m`, `/proc/loadavg` o `ksysguard`.

### 4. Portapapeles y Selección de Texto (Klipper / Wayland) 📋 (Completado ✅)
- [x] **Gestión y consulta inteligente del portapapeles:**
  - *"¿Qué tengo en el portapapeles?"* o *"¿Qué texto tengo seleccionado?"*.
  - *"Historial del portapapeles"* o *"Copia este texto al portapapeles"*.
  - **Implementación:** Integración nativa sin dependencias pesadas vía D-Bus de Klipper (`org.kde.klipper`), con soporte para selección primaria en Wayland (`wl-clipboard`) y X11 (`xclip`).

### 5. Adjuntar y Leer Archivos Locales (PDFs, Código, Documentos) 📎 (Completado ✅)
- [x] **Subida y adjunto de archivos locales desde la interfaz:**
  - Botón de clip 📎 (`mail-attachment`) en la barra inferior para seleccionar cualquier archivo del disco con `kdialog`.
  - Chip/badge visual con el nombre del archivo adjunto y botón para desadjuntarlo.
  - Ingesta automática de texto para PDFs (`pdftotext`), código fuente (`.py`, `.js`, `.ts`, `.sh`, etc.), markdown, texto plano, JSON, CSV y logs.
  - Soporte multimodal automático si el archivo adjunto es una imagen (`.png`, `.jpg`, `.webp`).
- [x] **Herramienta de lectura de archivos (`read_file_content`):**
  - El modelo puede leer archivos locales bajo demanda (*"Léete el archivo factura.pdf y resúmelo"*).

### 6. Búsqueda Rápida de Archivos en Local 🔎 (Completado ✅)
- [x] **Búsqueda de documentos y descargas:**
  - *"Encuentra el PDF que descargué hoy"* o *"Busca el archivo 'proyecto' y ábrelo"*.
  - **Implementación:** Integración híbrida con `baloosearch6` (motor indexado nativo de KDE Plasma 6) y búsqueda por nombre `find` acotada a `$HOME`, con apertura automática mediante `xdg-open` / `kde-open`.

### 7. Información Meteorológica (Clima) ☀️
- [ ] **Consulta meteorológica en lenguaje natural:**
  - *"¿Qué tiempo hace en Valencia?"*, *"¿Va a llover hoy?"*.
  - **Implementación:** API ultraligera JSON de `wttr.in/<ciudad>?format=j1` sin claves de API externas.

---

## 🎨 Mejoras de Interfaz y Experiencia de Usuario (UX)

- [x] **Diálogo de configuración nativo de KDE (Settings) ✅:**
  - URL personalizada de Ollama (para localhost o servidor remoto en red local).
  - Selector de idioma preferido de respuesta (Automático / Inglés / Español).
  - Instrucciones personalizadas (System Prompt configurable).
  - Botón de ajustes ⚙️ en la cabecera y menú contextual nativo de KDE Plasma.
- [x] **Fijar ventana en pantalla (Modo Chincheta / Pin 📌) ✅:**
  - Botón en la cabecera para congelar la ventana del asistente (`hideOnWindowDeactivate: !root.isPinned`).
  - Previene el cierre involuntario al perder el foco para trabajar en paralelo con otras aplicaciones o seleccionar archivos.
- [ ] Atajo de teclado global dedicado para invocar a Bonsai (`Meta + Space` o configurable).
- [ ] Historial de conversaciones guardado entre sesiones (opcional).
