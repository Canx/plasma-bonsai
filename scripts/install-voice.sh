#!/usr/bin/env bash
set -e

DEST_DIR="$HOME/.local/share/plasma-bonsai"
BIN_DIR="$DEST_DIR/bin"
MODELS_DIR="$DEST_DIR/models"

mkdir -p "$BIN_DIR" "$MODELS_DIR"

echo "=== Instalador de Componentes de Voz Offline para Plasma Bonsai ==="

# 1. Comprobar si ya existe Whisper
if command -v whisper &>/dev/null || command -v whisper-cli &>/dev/null || [ -f "$BIN_DIR/whisper-cli" ]; then
    echo "✓ Whisper (Speech-to-Text) ya está disponible en el sistema."
else
    echo "Descargando modelo Whisper Tiny para transcripción ultrarrápida..."
    curl -L --progress-bar -o "$MODELS_DIR/ggml-tiny.bin" \
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin"
    echo "✓ Modelo Whisper Tiny descargado en $MODELS_DIR/ggml-tiny.bin"
fi

# 2. Comprobar sintetizador de voz (TTS)
if command -v piper &>/dev/null || [ -f "$BIN_DIR/piper" ]; then
    echo "✓ Piper TTS ya está disponible."
elif command -v spd-say &>/dev/null; then
    echo "✓ Sistema nativo spd-say detectado para síntesis de voz."
else
    echo "Consejo: Puedes instalar 'speech-dispatcher' o 'piper' para síntesis de voz neuronal."
fi

echo "✓ Configuración de voz completada."
