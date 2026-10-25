#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLASMOID_DIR="$DIR/plasmoid"
ID="org.kde.plasma.bonsai"

echo "=== Modo Desarrollo: Plasma Bonsai Assistant ==="

# Asegurar que el Plasmoid está instalado en el usuario para testing
if command -v kpackagetool6 &>/dev/null; then
    TOOL="kpackagetool6"
elif command -v kpackagetool5 &>/dev/null; then
    TOOL="kpackagetool5"
else
    echo "Error: kpackagetool no encontrado."
    exit 1
fi

$TOOL --type Plasma/Applet --upgrade "$PLASMOID_DIR" 2>/dev/null || $TOOL --type Plasma/Applet --install "$PLASMOID_DIR" 2>/dev/null || true

# Comprobar si el demonio ya está corriendo
if ! curl -s http://127.0.0.1:11435/health &>/dev/null; then
    echo "Iniciando demonio en segundo plano..."
    python3 "$DIR/daemon/server.py" &
    DAEMON_PID=$!
    trap "kill $DAEMON_PID 2>/dev/null || true" EXIT
    sleep 1
else
    echo "Demonio ya activo en http://127.0.0.1:11435"
fi

echo "Abriendo widget en ventana aislada (plasmawindowed)..."
plasmawindowed "$ID"
