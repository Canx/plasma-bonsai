#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== Recargando Plasma Bonsai en el Escritorio ==="
"$DIR/scripts/package.sh"
"$DIR/scripts/install.sh"
echo "✓ Todo actualizado y recargado con éxito."
