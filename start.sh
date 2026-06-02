#!/bin/bash
# start.sh — Lanza el servidor y abre el navegador automáticamente
#
# Si el servidor ya está corriendo, solamente abre la pestaña en el navegador.
# Si no, inicia el servidor y abre el navegador.
#
# Uso:
#   ./start.sh                 # Puerto 8080
#   ./start.sh 3000            # Puerto personalizado
#   ./start.sh --port 3000     # Forma explícita

set -euo pipefail

# ─── Configuración ───────────────────────────────────────────────────────────

PORT=8080
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVE_SCRIPT="$PROJECT_DIR/serve.sh"
URL="http://localhost:$PORT"
SERVER_PID=

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case "$1" in
        --port|-p)  PORT="$2"; URL="http://localhost:$PORT"; shift 2 ;;
        --help|-h)  head -12 "$0" | tail -10; exit 0 ;;
        *)  if [[ "$1" =~ ^[0-9]+$ ]]; then
                PORT="$1"; URL="http://localhost:$PORT"; shift
            else
                echo "❌ Argumento desconocido: $1"; exit 1
            fi ;;
    esac
done

# ─── Detectar si el servidor ya está corriendo ──────────────────────────────

is_server_running() {
    # Verificar si el puerto está escuchando
    if ! lsof -ti :"$PORT" &>/dev/null; then
        return 1
    fi
    # Verificar que responde HTTP (doble chequeo)
    if curl -s -o /dev/null --max-time 2 "$URL" 2>/dev/null; then
        return 0
    fi
    return 1
}

# ─── Main ────────────────────────────────────────────────────────────────────

echo "╔══════════════════════════════════════════╗"
echo "║   🌍 Earth — Lanzador                   ║"
echo "╚══════════════════════════════════════════╝"
echo ""

if is_server_running; then
    echo "  ✅ Servidor activo en $URL"
else
    echo "  🚀 Iniciando servidor en $URL ..."
    echo ""

    # Verificar que serve.sh existe
    if [[ ! -f "$SERVE_SCRIPT" ]]; then
        echo "❌ No se encuentra serve.sh en $PROJECT_DIR"
        exit 1
    fi

    # Iniciar el servidor en segundo plano (sin --open, lo abrimos al final)
    "$SERVE_SCRIPT" --port "$PORT" &
    SERVER_PID=$!

    # Esperar a que arranque (máx 10 segundos)
    echo -n "  ⏳ Esperando al servidor"
    for i in $(seq 1 10); do
        if curl -s -o /dev/null --max-time 1 "$URL" 2>/dev/null; then
            echo ""
            echo "  ✅ Servidor listo"
            break
        fi
        echo -n "."
        sleep 1
    done

    # Si no arrancó, mostrar error
    if ! curl -s -o /dev/null --max-time 1 "$URL" 2>/dev/null; then
        echo ""
        echo "❌ El servidor no arrancó. Revisá si $PORT está ocupado:"
        echo "   lsof -ti :$PORT | xargs kill -9"
        exit 1
    fi
fi

# ─── Abrir navegador ─────────────────────────────────────────────────────────

echo ""
echo "  🌐 Abriendo $URL ..."
open "$URL"
echo ""
echo "📌 Servidor activo en $URL"
if [[ -n "${SERVER_PID:-}" ]]; then
    echo "   Para detenerlo: kill $SERVER_PID 2>/dev/null || lsof -ti :$PORT | xargs kill -9"
else
    echo "   Para detenerlo: lsof -ti :$PORT | xargs kill -9"
fi
echo ""
