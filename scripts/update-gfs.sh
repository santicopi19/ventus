#!/bin/bash
# update-gfs.sh — Descarga y convierte datos GFS de viento en un solo comando
#
# Uso:
#   ./scripts/update-gfs.sh              # Descarga datos de la última corrida disponible
#   ./scripts/update-gfs.sh --type temp   # Descarga temperatura
#   ./scripts/update-gfs.sh --hour 00     # Forzar hora específica (00, 06, 12, 18)
#   ./scripts/update-gfs.sh --check       # Solo verifica prerequisitos
#
# Requiere: Java (JRE), grib2json (ver Dockerfile para instalación automatizada)
#
# Variables de entorno:
#   GRIB2JSON_HOME  Path al directorio de grib2json (default: /opt/grib2json)
#   JAVA_HOME       Path al JDK/JRE (default: auto-detect)

set -euo pipefail

# ─── Configuración ───────────────────────────────────────────────────────────

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATA_DIR="$PROJECT_DIR/public/data/weather/current"
GRIB2JSON_HOME="${GRIB2JSON_HOME:-/opt/grib2json}"

# En Docker, use el Java del sistema; en macOS, buscar en Homebrew
if command -v java &>/dev/null; then
    JAVA_CMD="java"
else
    JAVA_CMD="${JAVA_HOME:-/opt/homebrew/opt/openjdk}/bin/java"
fi

# Tipo de dato: "wind" o "temp" (por defecto: wind)
TYPE="wind"
# Hora específica (vacío = auto-detect)
FORCE_HOUR=""
# Solo check
CHECK_ONLY=false

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case "$1" in
        --type|-t)   TYPE="$2"; shift 2 ;;
        --hour|-h)   FORCE_HOUR="$2"; shift 2 ;;
        --check|-c)  CHECK_ONLY=true; shift ;;
        --help)      head -20 "$0"; exit 0 ;;
        *)           echo "❌ Argumento desconocido: $1"; exit 1 ;;
    esac
done

# ─── Prerequisitos ───────────────────────────────────────────────────────────

check_prereqs() {
    local ok=true

    if ! $JAVA_CMD -version &>/dev/null 2>&1; then
        echo "❌ Java no encontrado."
        ok=false
    else
        echo "✅ Java: OK ($($JAVA_CMD -version 2>&1 | head -1))"
    fi

    if [[ ! -f "$GRIB2JSON_HOME/bin/grib2json" ]]; then
        echo "❌ grib2json no encontrado en $GRIB2JSON_HOME"
        ok=false
    else
        echo "✅ grib2json: OK ($GRIB2JSON_HOME/bin/grib2json)"
    fi

    if [[ ! -d "$DATA_DIR" ]]; then
        echo "❌ Directorio de datos no existe: $DATA_DIR"
        ok=false
    else
        echo "✅ Directorio datos: OK ($DATA_DIR)"
    fi

    if ! curl -s -o /dev/null --connect-timeout 5 "https://nomads.ncep.noaa.gov/" 2>/dev/null; then
        echo "⚠️  NOMADS no responde (se intentará igual)"
    else
        echo "✅ NOMADS: OK"
    fi

    if ! $ok; then
        echo ""
        echo "❌ Prerequisitos faltantes."
        exit 1
    fi
}

# ─── Detectar última hora GFS disponible ────────────────────────────────────

detect_hour() {
    local ymd="$1"
    local h=$(date -u +%H)
    h=$(( h / 6 * 6 ))

    local var_params
    if [[ "$TYPE" == "temp" ]]; then
        var_params="lev_2_m_above_ground=on&var_TMP=on"
    else
        var_params="lev_10_m_above_ground=on&var_UGRD=on&var_VGRD=on"
    fi

    for hour in $(printf "%02d\n%02d\n%02d\n%02d\n%02d" "$h" 18 12 06 00 | sort -rn | uniq); do
        local url="https://nomads.ncep.noaa.gov/cgi-bin/filter_gfs_1p00.pl?file=gfs.t${hour}z.pgrb2.1p00.f000&${var_params}&dir=%2Fgfs.${ymd}%2F${hour}%2Fatmos"
        local status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "$url" 2>/dev/null || echo "000")
        if [[ "$status" == "200" ]]; then
            printf "%s" "$hour"
            return 0
        fi
    done
    return 1
}

# ─── Descargar GRIB2 ─────────────────────────────────────────────────────────

download_grib() {
    local ymd="$1"
    local hour="$2"
    local tmpfile="$3"

    local lev_opt var_opt
    if [[ "$TYPE" == "temp" ]]; then
        lev_opt="lev_2_m_above_ground=on"
        var_opt="var_TMP=on"
    else
        lev_opt="lev_10_m_above_ground=on"
        var_opt="var_UGRD=on&var_VGRD=on"
    fi

    local url="https://nomads.ncep.noaa.gov/cgi-bin/filter_gfs_1p00.pl?file=gfs.t${hour}z.pgrb2.1p00.f000&${lev_opt}&${var_opt}&dir=%2Fgfs.${ymd}%2F${hour}%2Fatmos"

    echo "⬇️  Descargando GFS ${ymd} ${hour}:00Z..."
    echo "   URL: $url"
    echo ""

    curl -f -s -S -o "$tmpfile" \
        --connect-timeout 30 \
        --max-time 120 \
        "$url" || {
        echo "❌ Error descargando datos GFS para ${ymd} ${hour}:00Z"
        return 1
    }

    local size=$(stat -c%s "$tmpfile" 2>/dev/null || stat -f%z "$tmpfile" 2>/dev/null)
    echo "   Descargado: ${size} bytes"
    return 0
}

# ─── Convertir a JSON ────────────────────────────────────────────────────────

convert_json() {
    local grib="$1"

    local output_file
    if [[ "$TYPE" == "temp" ]]; then
        output_file="/tmp/current-temp-surface-level-gfs-1.0.json"
    else
        output_file="/tmp/current-wind-surface-level-gfs-1.0.json"
    fi

    echo "🔄 Convirtiendo a JSON..."

    "$GRIB2JSON_HOME/bin/grib2json" -d -n \
        -o "$output_file" \
        "$grib" 2>/dev/null || {
        echo "❌ Error en conversión grib2json" >&2
        return 1
    }

    local size=$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file" 2>/dev/null)
    echo "   JSON generado: ${size} bytes"
}

# ─── Copiar al proyecto ──────────────────────────────────────────────────────

copy_to_project() {
    local filename
    if [[ "$TYPE" == "temp" ]]; then
        filename="current-temp-surface-level-gfs-1.0.json"
    else
        filename="current-wind-surface-level-gfs-1.0.json"
    fi

    local json="/tmp/$filename"
    local dest="$DATA_DIR/$filename"

    if [[ ! -f "$json" ]]; then
        echo "❌ Archivo JSON temporario no encontrado: $json" >&2
        return 1
    fi

    # Backup del archivo anterior si existe
    if [[ -f "$dest" ]]; then
        local bak="$dest.bak"
        cp "$dest" "$bak"
        echo "   Backup: $bak"
    fi

    cp "$json" "$dest"
    echo "✅ Copiado a: $dest"

    # Mostrar fecha del dato
    python3 -c "
import json
with open('$dest') as f:
    data = json.load(f)
header = data[0]['header'] if isinstance(data, list) else data.get('header', {})
ref = header.get('refTime', 'N/A')
print(f'📅 Fecha del dato: {ref}')
print(f'📊 Registros: {len(data) if isinstance(data, list) else \"N/A\"}')
" 2>/dev/null || echo "   (no se pudo leer fecha)"
}

# ─── Main ────────────────────────────────────────────────────────────────────

echo "╔══════════════════════════════════════╗"
echo "║   Ventus — Actualizar Datos GFS      ║"
echo "╚══════════════════════════════════════╝"
echo ""

check_prereqs
echo ""

if $CHECK_ONLY; then
    echo "✅ Todos los prerequisitos están OK."
    exit 0
fi

# Detectar fecha y hora
YYYYMMDD=$(date -u +%Y%m%d)

if [[ -n "$FORCE_HOUR" ]]; then
    HOUR="$FORCE_HOUR"
    echo "🕐 Hora forzada: ${HOUR}:00Z"
else
    echo "🔍 Detectando última corrida GFS disponible..."
    HOUR=$(detect_hour "$YYYYMMDD") || {
        echo "❌ No se encontraron datos GFS disponibles para hoy (${YYYYMMDD})."
        echo "   Probá con --hour para especificar una hora."
        exit 1
    }
    echo "✅ Corrida más reciente: ${YYYYMMDD} ${HOUR}:00Z"
fi
echo ""

# Temp file
GRIB_TMP=$(mktemp /tmp/gfs_data.XXXXXX)
trap "rm -f $GRIB_TMP" EXIT

# Ejecutar pipeline
download_grib "$YYYYMMDD" "$HOUR" "$GRIB_TMP" || exit 1
convert_json "$GRIB_TMP" || exit 1
copy_to_project || exit 1

echo ""
echo "🎉 ¡Datos actualizados exitosamente!"
