#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLASMOID_DIR="$DIR/plasmoid"
ID="org.kde.plasma.bonsai"

echo "=== Modo Desarrollo: Plasma Bonsai Assistant (Standalone) ==="

# Asegurar permisos
chmod +x "$PLASMOID_DIR/contents/code/tools.py" 2>/dev/null || true

# Asegurar herramienta
if command -v kpackagetool6 &>/dev/null; then
    TOOL="kpackagetool6"
elif command -v kpackagetool5 &>/dev/null; then
    TOOL="kpackagetool5"
else
    echo "Error: kpackagetool no encontrado."
    exit 1
fi

$TOOL --type Plasma/Applet --upgrade "$PLASMOID_DIR" 2>/dev/null || $TOOL --type Plasma/Applet --install "$PLASMOID_DIR" 2>/dev/null || true

# Comprobar si Ollama está corriendo
if ! curl -s http://127.0.0.1:11434/api/tags &>/dev/null; then
    echo "⚠️ Aviso: Ollama no parece estar en ejecución en http://127.0.0.1:11434"
    echo "Puedes iniciarlo con: ollama serve"
else
    echo "✓ Ollama detectado en http://127.0.0.1:11434"
fi

echo "Abriendo widget en ventana aislada (plasmawindowed)..."
plasmawindowed "$ID"
