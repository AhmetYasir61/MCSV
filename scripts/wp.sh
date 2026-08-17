#!/usr/bin/env bash
# wpscript'i PATH'te olmasa da bulup calistirir; bellek ve headless ayarlarini
# kendisi verir.
#
#   ./scripts/wp.sh worldpainter/probe_layers.js
#   ./scripts/wp.sh worldpainter/import_tiles.js build/manifest.json out/GoT-World worldpainter/layer_map.json
#
# Bellegi degistirmek icin: WP_MEMORY_GB=8 ./scripts/wp.sh ...
set -euo pipefail

find_wpscript() {
    command -v wpscript 2>/dev/null && return 0
    for p in /opt/worldpainter/wpscript /usr/local/worldpainter/wpscript \
             /usr/share/worldpainter/wpscript /opt/WorldPainter/wpscript; do
        [[ -x "$p" ]] && { echo "$p"; return 0; }
    done
    # Son care: bilinen koklerde ara (find, ilk eslesmede durur).
    for root in /opt /usr/local /usr/share /root; do
        [[ -d "$root" ]] || continue
        local hit
        hit="$(find "$root" -maxdepth 4 -name 'wpscript*' -type f -perm -u+x 2>/dev/null | head -1)"
        [[ -n "$hit" ]] && { echo "$hit"; return 0; }
    done
    return 1
}

WP="${WPSCRIPT:-$(find_wpscript || true)}"
if [[ -z "$WP" ]]; then
    cat >&2 <<MSG
wpscript bulunamadi.

Nerede oldugunu gormek icin:
  find / -name 'wpscript*' -type f 2>/dev/null | head

Bulduktan sonra ya PATH'e ekleyin ya da:
  WPSCRIPT=/tam/yol/wpscript ./scripts/wp.sh <betik> ...

WorldPainter kurulu degilse: sudo ./scripts/setup_server.sh
MSG
    exit 1
fi

MEM_GB="${WP_MEMORY_GB:-}"
if [[ -z "$MEM_GB" ]]; then
    TOTAL_GB="$(free -g | awk '/^Mem:/ {print $2}')"
    MEM_GB=$(( TOTAL_GB * 7 / 10 ))
    [[ $MEM_GB -lt 2 ]] && MEM_GB=2
fi

echo "wpscript : $WP"
echo "bellek   : ${MEM_GB}G"
export JAVA_OPTS="-Xmx${MEM_GB}G -Djava.awt.headless=true"
exec "$WP" "$@"
