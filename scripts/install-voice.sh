#!/usr/bin/env bash
set -e

DEST_DIR="$HOME/.local/share/plasma-bonsai"
BIN_DIR="$DEST_DIR/bin"
MODELS_DIR="$DEST_DIR/models"

mkdir -p "$BIN_DIR" "$MODELS_DIR"

echo "=== Instalador de Componentes de Voz Offline para Plasma Bonsai ==="

# 1. Comprobar / Enlazar whisper-cli
WHISPER_CLI=""
if [ -x "$BIN_DIR/whisper-cli" ]; then
    WHISPER_CLI="$BIN_DIR/whisper-cli"
elif command -v whisper-cli &>/dev/null; then
    WHISPER_CLI="$(command -v whisper-cli)"
elif [ -x "/home/linuxbrew/.linuxbrew/bin/whisper-cli" ]; then
    ln -sf "/home/linuxbrew/.linuxbrew/bin/whisper-cli" "$BIN_DIR/whisper-cli"
    WHISPER_CLI="$BIN_DIR/whisper-cli"
fi

if [ -n "$WHISPER_CLI" ]; then
    echo "✓ whisper-cli (C++ de alto rendimiento) detectado en $WHISPER_CLI."
elif command -v brew &>/dev/null; then
    echo "Instalando whisper-cpp mediante Homebrew..."
    NONINTERACTIVE=1 brew install whisper-cpp
    if [ -x "/home/linuxbrew/.linuxbrew/bin/whisper-cli" ]; then
        ln -sf "/home/linuxbrew/.linuxbrew/bin/whisper-cli" "$BIN_DIR/whisper-cli"
        echo "✓ whisper-cli instalado y enlazado correctamente."
    fi
else
    echo "Aviso: No se encontró 'whisper-cli'. Puedes instalarlo con 'brew install whisper-cpp' o compilarlo desde https://github.com/ggerganov/whisper.cpp"
fi

# 2. Descargar modelo GGML si no existe
if [ ! -f "$MODELS_DIR/ggml-tiny.bin" ] && [ ! -f "$MODELS_DIR/ggml-base.bin" ]; then
    echo "Descargando modelo Whisper Tiny cuantizado (75 MB) para transcripción en tiempo real..."
    curl -L --progress-bar -o "$MODELS_DIR/ggml-tiny.bin" \
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin"
    echo "✓ Modelo Whisper Tiny descargado en $MODELS_DIR/ggml-tiny.bin"
else
    echo "✓ Modelo Whisper cuantizado ya disponible en $MODELS_DIR"
fi

# 3. Comprobar sintetizador de voz (TTS)
if command -v piper &>/dev/null || [ -f "$BIN_DIR/piper" ]; then
    echo "✓ Piper TTS ya está disponible."
elif command -v spd-say &>/dev/null; then
    echo "✓ Sistema nativo spd-say detectado para síntesis de voz."
else
    echo "Consejo: Puedes instalar 'speech-dispatcher' (spd-say) o 'piper' para síntesis de voz."
fi

echo "✓ Configuración de voz completada."
