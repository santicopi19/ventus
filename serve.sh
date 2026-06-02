#!/bin/bash
# serve.sh — Inicia servidor de desarrollo con cache-busting automático
#
# Reemplaza dinámicamente ?v=N por ?v=TIMESTAMP en los HTML servidos,
# así nunca hay problemas de caché del navegador con JS/CSS.
# Todos los archivos se sirven con headers anti-cache.
#
# Uso:
#   ./serve.sh                  # Puerto 8080
#   ./serve.sh --port 3000      # Puerto personalizado
#   ./serve.sh --open           # Abre el navegador automáticamente
#
# Requiere: Python 3

set -euo pipefail

PORT=8080
OPEN_BROWSER=false
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PUBLIC_DIR="$PROJECT_DIR/public"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --port|-p)  PORT="$2"; shift 2 ;;
        --open|-o)  OPEN_BROWSER=true; shift ;;
        --help)     head -15 "$0"; exit 0 ;;
        *)          echo "❌ Argumento desconocido: $1"; exit 1 ;;
    esac
done

if [[ ! -d "$PUBLIC_DIR" ]]; then
    echo "❌ No se encuentra el directorio public/ en $PROJECT_DIR"
    exit 1
fi

# ─── Servidor Python con cache-busting ──────────────────────────────────────

echo "╔══════════════════════════════════════════════════╗"
echo "║   🌍 Earth Dev Server — Cache-busting activo    ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

python3 -c "
import http.server
import re
import time
import os
import sys

PORT = int(os.environ.get('PORT', $PORT))
PUBLIC = os.environ.get('PUBLIC_DIR', '$PUBLIC_DIR')
TS = str(int(time.time()))

os.chdir(PUBLIC)

class CacheBustHandler(http.server.SimpleHTTPRequestHandler):
    \"\"\"Reemplaza ?v=N por ?v=TIMESTAMP en archivos HTML servidos.\"\"\"

    def do_GET(self):
        path = self.translate_path(self.path)

        # Solo interceptar archivos HTML
        if path.endswith('.html') and os.path.isfile(path):
            try:
                with open(path, 'rb') as f:
                    content = f.read()
                # Reemplazar ?v=NUmero por ?v=TIMESTAMP en src/href de JS y CSS
                modified = re.sub(
                    rb'\\.(js|css)\\?v=[0-9a-zA-Z._-]+',
                    rb'.\\\\1?v=' + TS.encode(),
                    content
                )
                self.send_response(200)
                self.send_header('Content-Type', 'text/html; charset=utf-8')
                self.send_header('Content-Length', str(len(modified)))
                # Los headers anti-cache los agrega end_headers() automáticamente
                self.end_headers()
                self.wfile.write(modified)
                return
            except Exception as e:
                print(f'Error procesando {path}: {e}', file=sys.stderr)
                # Fallback al comportamiento default
                pass

        # Para todos los demás archivos, comportamiento normal
        super().do_GET()

    def end_headers(self):
        # Agregar headers anti-cache a absolutamente todos los archivos servidos
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

# Bind y arrancar con http.server.HTTPServer (permite reuso de dirección)
try:
    with http.server.HTTPServer(('', PORT), CacheBustHandler) as httpd:
        httpd.allow_reuse_address = True
        print(f'  📡 Servidor: http://localhost:{PORT}')
        print(f'  📁 Directorio: {PUBLIC}')
        print(f'  🔄 Cache-busting: activo (v={TS})')
        print(f'  ⌨️  Ctrl+C para detener')
        print()
        httpd.serve_forever()
except OSError as e:
    if 'Address already in use' in str(e):
        print(f'❌ Puerto {PORT} en uso. ¿Ya hay un servidor corriendo?')
        print(f'   Para matarlo: lsof -ti :{PORT} | xargs kill -9')
    else:
        print(f'❌ Error: {e}')
    sys.exit(1)
" &

SERVER_PID=$!

# Abrir navegador si se pidió
if $OPEN_BROWSER; then
    sleep 1
    echo "  🌐 Abriendo navegador..."
    open "http://localhost:$PORT"
fi

# Esperar y manejar Ctrl+C limpio
wait $SERVER_PID 2>/dev/null || true
echo ""
echo "👋 Servidor detenido."
