#!/usr/bin/env bash
# Haritayi ayri, klonlanabilir bir depoya kurar ve ilk release'i acar.
#
#   ./scripts/setup_map_repo.sh [repo-adi]
#
# Neden ayri depo: MCSV karisik icerikli; harita paketini tek basina klonlamak
# ve release'ten indirmek isteyenler icin temiz bir depo daha pratik.
# Bu betigi calistiran hesabin `gh auth login` ile giris yapmis olmasi gerekir.
set -euo pipefail

REPO="${1:-westeros-world-maps}"
OWNER="$(gh api user --jq .login)"
SRC="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"

echo "==> $OWNER/$REPO olusturuluyor"
gh repo create "$OWNER/$REPO" --public \
  --description "Game of Thrones (Westeros & Essos) Minecraft dünya üreteci" || true

echo "==> icerik kopyalaniyor"
rsync -a --exclude .git --exclude build --exclude out --exclude preview "$SRC"/ "$TMP"/

cd "$TMP"
git init -q
git add -A
git commit -qm "Westeros & Essos Minecraft dunya ureteci"
git branch -M main
git remote add origin "https://github.com/$OWNER/$REPO.git"
git push -u origin main

echo "==> release aciliyor"
if ls source/*.png >/dev/null 2>&1; then
  python3 tools/mapgen.py "$(ls source/*.png | head -1)" --out build/ --scale 16
  python3 tools/make_preview.py build/ --out preview/index.html
  zip -qr westeros-tiles.zip build/
  gh release create v0.1.0 westeros-tiles.zip preview/index.html \
     --repo "$OWNER/$REPO" \
     --title "Westeros & Essos v0.1.0" \
     --notes "Harita karolari (heightmap + biome + vejetasyon maskeleri) ve tarayicida acilan onizleme."
else
  echo "source/ altinda PNG yok — release'i kaynak haritayi ekledikten sonra acin:" >&2
  echo "  cp <harita>.png $TMP/source/ && ./scripts/setup_map_repo.sh $REPO" >&2
fi

echo "==> bitti: https://github.com/$OWNER/$REPO"
echo "    klonlamak icin: git clone https://github.com/$OWNER/$REPO.git"
