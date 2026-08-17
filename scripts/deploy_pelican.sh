#!/usr/bin/env bash
# Uretilen Minecraft dunyasini Debian uzerindeki Pelican Panel (Wings) sunucusuna
# kurar.
#
#   sudo ./scripts/deploy_pelican.sh --uuid <sunucu-uuid> --world out/GoT-World
#   sudo ./scripts/deploy_pelican.sh --volume /var/lib/pelican/volumes/<uuid> --world out/GoT-World
#
# Yaptigi is:
#   1) Sunucu volume dizinini bulur (Pelican: /var/lib/pelican/volumes/<uuid>).
#   2) Varsa eski dunyayi zaman damgali yedege alir.
#   3) Dunyayi <volume>/<level-name> olarak kopyalar.
#   4) server.properties icinde level-name / level-type degerlerini ayarlar.
#   5) Dosya sahipligini volume dizininkiyle ayni yapar (Wings konteyneri o
#      kullaniciyla calisir; yanlis sahiplik "permission denied" demektir).
#
# Sunucu KAPALI olmali. Acikken kopyalamak dunyayi bozar.
set -euo pipefail

UUID=""
VOLUME=""
WORLD=""
LEVEL_NAME="world"
DATA_ROOT="/var/lib/pelican/volumes"
DRY_RUN=0

usage() {
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --uuid)       UUID="$2"; shift 2 ;;
        --volume)     VOLUME="$2"; shift 2 ;;
        --world)      WORLD="$2"; shift 2 ;;
        --level-name) LEVEL_NAME="$2"; shift 2 ;;
        --data-root)  DATA_ROOT="$2"; shift 2 ;;
        --dry-run)    DRY_RUN=1; shift ;;
        -h|--help)    usage ;;
        *) echo "bilinmeyen secenek: $1" >&2; usage ;;
    esac
done

[[ -n "$WORLD" ]] || { echo "--world zorunlu" >&2; usage; }
[[ -d "$WORLD" ]] || { echo "dunya klasoru yok: $WORLD" >&2; exit 1; }
# WorldPainter export'u level.dat + region/ icerir; yanlis klasoru kopyalamayalim.
[[ -f "$WORLD/level.dat" ]] || {
    echo "level.dat yok: $WORLD" >&2
    echo "WorldPainter'in disa aktardigi dunya klasorunu verin (icinde level.dat ve region/ olmali)." >&2
    exit 1
}

if [[ -z "$VOLUME" ]]; then
    [[ -n "$UUID" ]] || { echo "--uuid ya da --volume gerekli" >&2; usage; }
    VOLUME="$DATA_ROOT/$UUID"
fi
[[ -d "$VOLUME" ]] || {
    echo "sunucu volume dizini yok: $VOLUME" >&2
    echo "Pelican kurulumu farkli bir dizin kullaniyorsa --data-root ile verin." >&2
    echo "Wings yapilandirmasindaki yolu gormek icin: grep -A2 'system:' /etc/pelican/config.yml" >&2
    exit 1
}

# Sahiplik: volume dizininin kendisinden okunur. Wings surumune gore uid/gid
# degisir (cogunlukla 988:988), sabit yazmak yerine mevcut duruma uyuyoruz.
OWNER="$(stat -c '%u:%g' "$VOLUME")"

TARGET="$VOLUME/$LEVEL_NAME"
PROPS="$VOLUME/server.properties"
STAMP="$(date +%Y%m%d-%H%M%S)"

echo "volume     : $VOLUME"
echo "hedef dunya: $TARGET"
echo "sahiplik   : $OWNER"
echo "boyut      : $(du -sh "$WORLD" | cut -f1)"

if [[ $DRY_RUN -eq 1 ]]; then
    echo "(dry-run: hicbir sey yazilmadi)"
    exit 0
fi

# Sunucunun kapali oldugunu kabaca dogrula: acik dunyada session.lock kilitli olur.
if command -v fuser >/dev/null 2>&1 && [[ -f "$TARGET/session.lock" ]]; then
    if fuser "$TARGET/session.lock" >/dev/null 2>&1; then
        echo "HATA: dunya su anda kullanimda gorunuyor. Sunucuyu panelden durdurun." >&2
        exit 1
    fi
fi

if [[ -e "$TARGET" ]]; then
    echo "eski dunya yedekleniyor -> $TARGET.bak-$STAMP"
    mv "$TARGET" "$TARGET.bak-$STAMP"
fi

echo "kopyalaniyor..."
if command -v rsync >/dev/null 2>&1; then
    rsync -a --info=progress2 "$WORLD"/ "$TARGET"/
else
    cp -a "$WORLD" "$TARGET"
fi

# server.properties: level-name dunya klasorunun adiyla ayni olmali; level-type
# flat/normal degil, WorldPainter dunyalarinda uretimi kapatmak icin genelde
# 'minecraft:flat' disinda birakilir ama chunk uretimi kenarlarda devam eder.
if [[ -f "$PROPS" ]]; then
    echo "server.properties guncelleniyor"
    if grep -q '^level-name=' "$PROPS"; then
        sed -i "s|^level-name=.*|level-name=$LEVEL_NAME|" "$PROPS"
    else
        echo "level-name=$LEVEL_NAME" >> "$PROPS"
    fi
else
    echo "UYARI: server.properties yok ($PROPS). Sunucu bir kez calistirilinca olusur;"
    echo "       sonra level-name=$LEVEL_NAME yapmayi unutmayin."
fi

echo "sahiplik ayarlaniyor: $OWNER"
chown -R "$OWNER" "$TARGET"
[[ -f "$PROPS" ]] && chown "$OWNER" "$PROPS"

echo ""
echo "Bitti."
echo "  Panelden sunucuyu baslatin."
echo "  Eski dunya: $TARGET.bak-$STAMP (sorun yoksa silebilirsiniz)"
