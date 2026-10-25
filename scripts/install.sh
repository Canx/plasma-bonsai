#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLASMOID_DIR="$DIR/plasmoid"
ID="org.kde.plasma.bonsai"

echo "=== Instalando Plasmoid: $ID (Modo Standalone / Espacio de Usuario) ==="

# Priorizar kpackagetool6 para KDE Plasma 6
if command -v kpackagetool6 &>/dev/null; then
    TOOL="kpackagetool6"
elif command -v kpackagetool5 &>/dev/null; then
    TOOL="kpackagetool5"
else
    echo "Error: kpackagetool no encontrado."
    exit 1
fi

echo "Usando herramienta: $TOOL"

# Desinstalar versión previa si existe
$TOOL --type Plasma/Applet --remove "$ID" 2>/dev/null || true
rm -rf "$HOME/.local/share/plasma/plasmoids/$ID"
rm -rf "$HOME/.local/share/$ID"

# Asegurar permisos de ejecución en scripts empaquetados
chmod +x "$PLASMOID_DIR/contents/code/tools.py" 2>/dev/null || true

# Instalar nueva versión
$TOOL --type Plasma/Applet --install "$PLASMOID_DIR"

# Limpiar servicio systemd anterior si existía (ya no es necesario demonio)
if [ -f "$HOME/.config/systemd/user/plasma-bonsai.service" ]; then
    systemctl --user stop plasma-bonsai.service 2>/dev/null || true
    systemctl --user disable plasma-bonsai.service 2>/dev/null || true
    rm -f "$HOME/.config/systemd/user/plasma-bonsai.service"
    systemctl --user daemon-reload 2>/dev/null || true
    echo "✓ Servicio demonio anterior eliminado (ya no se requiere demonio residente)."
fi

echo "✓ Plasmoid instalado correctamente en espacio de usuario."
echo "No requiere servicios adicionales en segundo plano. Se conecta directamente a Ollama (localhost:11434)."
