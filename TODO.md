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

### 4. Historial del Portapapeles (Klipper) 📋
- [ ] **Consulta de contenido copiado:**
  - *"¿Qué tengo en el portapapeles?"*.
  - *"Busca en el portapapeles el enlace que copié hace un rato"*.
  - **Implementación:** Interfaz D-Bus de Klipper (`org.kde.klipper`).

### 5. Búsqueda Rápida de Archivos en Local 🔎
- [ ] **Búsqueda de documentos y descargas:**
  - *"Encuentra el PDF que descargué hoy"* o *"Busca el archivo 'proyecto' en mi carpeta personal"*.
  - **Implementación:** Integración con `baloosearch` (motor de búsqueda indexada de KDE) o fallback a `fd` / `find` acotado a `$HOME`.

### 6. Información Meteorológica (Clima) ☀️
- [ ] **Consulta meteorológica en lenguaje natural:**
  - *"¿Qué tiempo hace en Valencia?"*, *"¿Va a llover hoy?"*.
  - **Implementación:** API ultraligera JSON de `wttr.in/<ciudad>?format=j1` sin claves de API externas.

---

## 🎨 Mejoras de Interfaz y Experiencia de Usuario (UX)

- [ ] Diálogo de configuración nativo de KDE (*Settings*) para personalizar:
  - URL personalizada de Ollama (por si está en otra máquina en red local).
  - Umbral o sensibilidad del micrófono para la voz.
  - Atajo de teclado global dedicado para invocar a Bonsai (`Meta + Space` o configurable).
- [ ] Historial de conversaciones guardado entre sesiones (opcional).
