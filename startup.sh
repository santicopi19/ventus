#!/bin/sh
# startup.sh — Ventus entrypoint with diagnostics
echo "=== VENTUS STARTUP ==="
echo "Node: $(node --version)"
echo "PORT env: ${PORT:-not set}"
echo "CWD: $(pwd)"
echo "Server.js exists: $(test -f server.js && echo yes || echo no)"
echo "node_modules/express exists: $(test -d node_modules/express && echo yes || echo no)"
echo "Java available: $(command -v java && java -version 2>&1 | head -1 || echo 'not found')"
echo "======================"
exec node server.js
