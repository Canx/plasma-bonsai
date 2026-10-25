#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLASMOID_DIR="$DIR/plasmoid"
ID="org.kde.plasma.bonsai"

echo "=== Instalando Plasmoid: $ID ==="

# Comprobar herramienta de empaquetado
if command -v kpackagetool5 &>/dev/null; then
    TOOL="kpackagetool5"
elif command -v kpackagetool6 &>/dev/null; then
    TOOL="kpackagetool6"
else
    echo "Error: kpackagetool no encontrado."
    exit 1
fi

# Desinstalar versión previa si existe
$TOOL --type Plasma/Applet --remove "$ID" 2>/dev/null || true

# Instalar nueva versión
$TOOL --type Plasma/Applet --install "$PLASMOID_DIR"

echo "✓ Plasmoid instalado correctamente."

# Configurar servicio systemd de usuario para el demonio
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_USER_DIR"

cat <<EOF > "$SYSTEMD_USER_DIR/plasma-bonsai.service"
[Unit]
Description=Plasma Bonsai AI Assistant Daemon
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 $DIR/daemon/server.py
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now plasma-bonsai.service

echo "✓ Demonio de usuario configurado y activado (plasma-bonsai.service)."
echo "Estado del servicio:"
systemctl --user status plasma-bonsai.service --no-pager
