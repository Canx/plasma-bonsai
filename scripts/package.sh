#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLASMOID_DIR="$DIR/plasmoid"
OUT_FILE="$DIR/plasma-bonsai.plasmoid"

echo "=== Generando paquete Plasmoid: $OUT_FILE ==="

# Limpiar posibles restos de caché python o temporales
find "$PLASMOID_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find "$PLASMOID_DIR" -type f -name "*.pyc" -delete 2>/dev/null || true
find "$PLASMOID_DIR" -type f -name "*~" -delete 2>/dev/null || true

# Asegurar permisos de ejecución en scripts de Python
chmod +x "$PLASMOID_DIR/contents/code/tools.py" 2>/dev/null || true

# Eliminar paquete anterior si existe
rm -f "$OUT_FILE"

# Generar archivo ZIP (.plasmoid) desde la raíz del plasmoid
cd "$PLASMOID_DIR"
zip -r -9 "$OUT_FILE" metadata.json contents/

echo "✓ Paquete generado con éxito: $OUT_FILE"
unzip -l "$OUT_FILE"
