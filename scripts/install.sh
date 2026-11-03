#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLASMOID_DIR="$DIR/plasmoid"
ID="com.github.canx.plasma-bonsai"

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

# Instalar iconos del sistema para KDE Plasma
mkdir -p "$HOME/.local/share/icons/hicolor/scalable/apps" "$HOME/.local/share/icons/hicolor/256x256/apps" 2>/dev/null || true
cp -f "$PLASMOID_DIR/contents/icons/plasma-bonsai.svg" "$HOME/.local/share/icons/hicolor/scalable/apps/plasma-bonsai.svg" 2>/dev/null || true
cp -f "$PLASMOID_DIR/contents/icons/plasma-bonsai.png" "$HOME/.local/share/icons/hicolor/256x256/apps/plasma-bonsai.png" 2>/dev/null || true

# Instalar nueva versión
$TOOL --type Plasma/Applet --install "$PLASMOID_DIR"

# Enlace simbólico de compatibilidad para instancias previas en panel
LEGACY_ID="org.kde.plasma.bonsai"
ln -sfn "$HOME/.local/share/plasma/plasmoids/$ID" "$HOME/.local/share/plasma/plasmoids/$LEGACY_ID" 2>/dev/null || true

# Limpiar caché de compilación QML e iconos para forzar lectura de cambios
rm -rf "$HOME/.cache/qmlcache" "$HOME/.cache/icon-cache.kcache" 2>/dev/null || true

# Reiniciar plasmashell automáticamente si está activo para aplicar cambios en caliente
if systemctl --user is-active --quiet plasma-plasmashell 2>/dev/null; then
    echo "↻ Recargando entorno de escritorio Plasma..."
    systemctl --user restart plasma-plasmashell --no-block 2>/dev/null || true
fi

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
