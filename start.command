#!/bin/bash
# start.command — Versión para hacer doble click en Finder (macOS)
#
# Comportamiento:
# - Si el servidor ya está corriendo → abre la pestaña en el navegador
# - Si no → inicia el servidor + abre el navegador
#
# La ventana de Terminal se mantiene abierta hasta presionar una tecla.

cd "$(dirname "$0")" || exit 1

echo "╔══════════════════════════════════════════╗"
echo "║   🌍 Earth — Lanzador (Finder)          ║"
echo "╚══════════════════════════════════════════╝"
echo ""

./start.sh

echo ""
echo "──────────────────────────────────────────"
echo "  Presioná Enter para cerrar esta ventana"
echo "──────────────────────────────────────────"
read -r
