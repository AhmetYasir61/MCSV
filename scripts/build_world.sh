#!/usr/bin/env bash
# Sunucuda uctan uca: haritadan karo/heightmap uret -> WorldPainter ile dunyayi
# olustur -> istege bagli olarak Pelican sunucusuna kur.
#
#   ./scripts/build_world.sh --source source/westeros.png --scale 16
#   ./scripts/build_world.sh --source source/westeros.png --scale 16 \
#       --deploy-uuid 218d2710-f789-43aa-88c6-02a3274551f0 --level-name GameOFThrones
#
# Onkosul: sudo ./scripts/setup_server.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE=""
SCALE=16
OUT_WORLD="$REPO_DIR/out/GoT-World"
BUILD_DIR="$REPO_DIR/build"
MEMORY_GB=""
WPSCRIPT=""
DEPLOY_UUID=""
LEVEL_NAME="world"
PREVIEW=1
MAP_FORMAT="${MAP_FORMAT:-}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --source)      SOURCE="$2"; shift 2 ;;
        --scale)       SCALE="$2"; shift 2 ;;
        --out)         OUT_WORLD="$2"; shift 2 ;;
        --build)       BUILD_DIR="$2"; shift 2 ;;
        --memory-gb)   MEMORY_GB="$2"; shift 2 ;;
        --wpscript)    WPSCRIPT="$2"; shift 2 ;;
        --deploy-uuid) DEPLOY_UUID="$2"; shift 2 ;;
        --level-name)  LEVEL_NAME="$2"; shift 2 ;;
        --no-preview)  PREVIEW=0; shift ;;
        --map-format)  MAP_FORMAT="$2"; shift 2 ;;
        -h|--help)     sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "bilinmeyen secenek: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$SOURCE" ]]; then
    SOURCE="$(ls "$REPO_DIR"/source/*.png 2>/dev/null | head -1 || true)"
fi
[[ -n "$SOURCE" && -f "$SOURCE" ]] || {
    echo "kaynak harita yok. --source ile verin ya da source/ altina koyun." >&2
    exit 1
}

PY="$REPO_DIR/.venv/bin/python3"
[[ -x "$PY" ]] || PY="$(command -v python3)"

# Bellek: verilmezse toplam RAM'in ~%70'i (isletim sistemine yer birakilir).
if [[ -z "$MEMORY_GB" ]]; then
    TOTAL_GB="$(free -g | awk '/^Mem:/ {print $2}')"
    MEMORY_GB=$(( TOTAL_GB * 7 / 10 ))
    [[ $MEMORY_GB -lt 2 ]] && MEMORY_GB=2
fi

if [[ -z "$WPSCRIPT" ]]; then
    WPSCRIPT="$(command -v wpscript || true)"
    [[ -z "$WPSCRIPT" && -x /opt/worldpainter/wpscript ]] && WPSCRIPT=/opt/worldpainter/wpscript
fi
[[ -n "$WPSCRIPT" ]] || { echo "wpscript bulunamadi. --wpscript ile yolunu verin." >&2; exit 1; }

echo "kaynak   : $SOURCE"
echo "olcek    : 1 piksel = $SCALE blok"
echo "bellek   : ${MEMORY_GB}G"
echo "wpscript : $WPSCRIPT"
echo ""

echo "==> 1/3 heightmap + katman maskeleri"
"$PY" "$REPO_DIR/tools/mapgen.py" "$SOURCE" --out "$BUILD_DIR" --scale "$SCALE"

if [[ $PREVIEW -eq 1 ]]; then
    echo "==> onizleme"
    "$PY" "$REPO_DIR/tools/make_preview.py" "$BUILD_DIR" --out "$REPO_DIR/preview/index.html"
fi

echo "==> 2/3 WorldPainter dunyasi"
# Basssiz sunucuda AWT ekran aramasin diye headless zorunlu.
export JAVA_OPTS="-Xmx${MEMORY_GB}G -Djava.awt.headless=true"
"$WPSCRIPT" "$REPO_DIR/worldpainter/import_tiles.js" \
    "$BUILD_DIR/manifest.json" "$OUT_WORLD" "$REPO_DIR/worldpainter/layer_map.json" \
    ${MAP_FORMAT:+"$MAP_FORMAT"}

if [[ -n "$DEPLOY_UUID" ]]; then
    echo "==> 3/3 Pelican sunucusuna kurulum"
    echo "    Sunucunun panelden DURDURULMUS olmasi gerekir."
    sudo "$REPO_DIR/scripts/deploy_pelican.sh" \
        --uuid "$DEPLOY_UUID" --world "$OUT_WORLD" --level-name "$LEVEL_NAME"
else
    echo "==> 3/3 atlandi (--deploy-uuid verilmedi)"
    echo "    Dunya: $OUT_WORLD"
fi

echo ""
echo "Bitti."
du -sh "$OUT_WORLD" 2>/dev/null || true
