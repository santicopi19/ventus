#!/bin/bash
# setup-cron.sh — Instala o remueve el cron job para actualización automática de datos GFS
#
# Uso:
#   ./scripts/setup-cron.sh install     # Instala el cron job (cada 6 horas a las 03, 09, 15, 21 UTC)
#   ./scripts/setup-cron.sh remove      # Remueve el cron job
#   ./scripts/setup-cron.sh status      # Muestra el estado actual del cron
#   ./scripts/setup-cron.sh logs        # Muestra las últimas ejecuciones del log
#
# El cron job ejecuta update-gfs.sh cada 6 horas.
# Los logs se guardan en: scripts/logs/gfs-update.log

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="$PROJECT_DIR/scripts"
LOG_DIR="$SCRIPTS_DIR/logs"
LOG_FILE="$LOG_DIR/gfs-update.log"
CRON_TAG="# earth-gfs-update"
CRON_SCHEDULE="3 */6 * * *"  # Cada 6 horas: 03:03, 09:03, 15:03, 21:03 (3 min después de la hora)

# ─── Help ────────────────────────────────────────────────────────────────────

show_help() {
    sed -n '2,10p' "$0"
    exit 0
}

# ─── Instalar ────────────────────────────────────────────────────────────────

install_cron() {
    echo "📦 Instalando cron job para actualización GFS..."

    # Crear directorio de logs
    mkdir -p "$LOG_DIR"

    # Rotar log si es muy grande (>10MB)
    if [[ -f "$LOG_FILE" ]] && [[ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null) -gt 10485760 ]]; then
        mv "$LOG_FILE" "$LOG_FILE.old"
        echo "   Log rotado (era >10MB): $LOG_FILE.old"
    fi

    # Escapar espacios con comillas simples (seguro para crontab + /bin/sh -c)
    local cron_entry="${CRON_SCHEDULE} cd '${PROJECT_DIR}' && ./scripts/update-gfs.sh >> '${LOG_FILE}' 2>&1 ${CRON_TAG}"

    # Verificar si ya está instalado
    if crontab -l 2>/dev/null | grep -qF "$CRON_TAG"; then
        echo "⚠️  El cron job ya está instalado. Se reemplazará."
        # Remover la línea existente
        (crontab -l 2>/dev/null | grep -vF "$CRON_TAG") | crontab -
    fi

    # Agregar la nueva entrada
    (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -

    # Verificar
    if crontab -l 2>/dev/null | grep -qF "$CRON_TAG"; then
        echo "✅ Cron job instalado:"
        echo "   Horario: ${CRON_SCHEDULE} (cada 6 horas a las 03, 09, 15, 21 UTC)"
        echo "   Script:  ${PROJECT_DIR}/scripts/update-gfs.sh"
        echo "   Log:     ${LOG_FILE}"
        echo ""
        echo "📋 Primera ejecución aproximada: dentro de las próximas 6 horas."
        echo "   Para probar ahora mismo: ./scripts/update-gfs.sh"
    else
        echo "❌ Error: No se pudo instalar el cron job."
        exit 1
    fi
}

# ─── Remover ─────────────────────────────────────────────────────────────────

remove_cron() {
    echo "🗑️  Removiendo cron job..."

    if crontab -l 2>/dev/null | grep -qF "$CRON_TAG"; then
        (crontab -l 2>/dev/null | grep -vF "$CRON_TAG") | crontab -
        echo "✅ Cron job removido."
    else
        echo "ℹ️  No había cron job instalado."
    fi
}

# ─── Status ──────────────────────────────────────────────────────────────────

show_status() {
    echo "📊 Estado del cron job GFS:"
    echo ""

    if crontab -l 2>/dev/null | grep -qF "$CRON_TAG"; then
        local entry
        entry=$(crontab -l 2>/dev/null | grep "$CRON_TAG")
        echo "   Estado:    ✅ ACTIVO"
        echo "   Horario:   ${CRON_SCHEDULE} (cada 6 horas)"
        echo "   Entrada:   $entry"
    else
        echo "   Estado:    ❌ NO INSTALADO"
    fi

    echo ""

    # Mostrar info del último log si existe
    if [[ -f "$LOG_FILE" ]]; then
        local last_run
        last_run=$(tail -1 "$LOG_FILE" 2>/dev/null || echo "N/A")
        local log_size
        log_size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null)
        echo "   Último log: ${last_run:0:100}"
        echo "   Tamaño log: $(numfmt --to=iec $log_size 2>/dev/null || echo "${log_size} bytes")"
        echo ""
        echo "   Últimas 5 líneas del log:"
        echo "   ──────────────────────────"
        tail -5 "$LOG_FILE" | sed 's/^/   /'
    fi
}

# ─── Logs ────────────────────────────────────────────────────────────────────

show_logs() {
    if [[ ! -f "$LOG_FILE" ]]; then
        echo "ℹ️  No hay logs todavía. El cron job se ejecutará según el horario programado."
        echo "   Para probar manualmente: ./scripts/update-gfs.sh"
        exit 0
    fi

    local lines=${1:-50}
    echo "📋 Últimas $lines líneas del log (${LOG_FILE}):"
    echo "   ─────────────────────────────────────────────"
    tail -n "$lines" "$LOG_FILE" | sed 's/^/   /'
}

# ─── Main ────────────────────────────────────────────────────────────────────

echo "╔══════════════════════════════════════════╗"
echo "║   🌍 Earth — Cron Job GFS               ║"
echo "╚══════════════════════════════════════════╝"
echo ""

case "${1:-help}" in
    install|--install|-i)
        install_cron
        ;;
    remove|--remove|-r|uninstall)
        remove_cron
        ;;
    status|--status|-s)
        show_status
        ;;
    logs|--logs|-l)
        show_logs "${2:-50}"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "❌ Argumento desconocido: $1"
        echo "   Usar: install | remove | status | logs"
        exit 1
        ;;
esac
