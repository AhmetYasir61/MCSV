#!/usr/bin/env bash
# Debian sunucuda dunya uretimi icin gerekli her seyi kurar:
# Python + bagimliliklar, Java ve WorldPainter (basssiz / headless).
#
#   sudo ./scripts/setup_server.sh
#   sudo ./scripts/setup_server.sh --installer-url https://.../worldpainter_2.27.0_amd64.deb
#
# WorldPainter indirme adresi surumle degisir; betik once verilen URL'yi, sonra
# bilinen kalibi dener, bulamazsa ne yapmaniz gerektigini soyler. Indirme
# adresini https://www.worldpainter.net/ adresinden dogrulayin.
set -euo pipefail

INSTALLER_URL=""
WP_VERSION="2.27.0"
INSTALL_DIR="/opt/worldpainter"
SKIP_APT=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --installer-url) INSTALLER_URL="$2"; shift 2 ;;
        --version)       WP_VERSION="$2"; shift 2 ;;
        --install-dir)   INSTALL_DIR="$2"; shift 2 ;;
        --skip-apt)      SKIP_APT=1; shift ;;
        -h|--help)       sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "bilinmeyen secenek: $1" >&2; exit 1 ;;
    esac
done

[[ $EUID -eq 0 ]] || { echo "root olarak calistirin (sudo)." >&2; exit 1; }

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
echo "==> depo: $REPO_DIR"

if [[ $SKIP_APT -eq 0 ]]; then
    echo "==> paketler kuruluyor"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq \
        python3 python3-pip python3-venv \
        default-jre-headless \
        rsync curl unzip ca-certificates tmux
fi

echo "==> python sanal ortami"
python3 -m venv "$REPO_DIR/.venv"
"$REPO_DIR/.venv/bin/pip" install --quiet --upgrade pip
"$REPO_DIR/.venv/bin/pip" install --quiet -r "$REPO_DIR/requirements.txt"
echo "    $REPO_DIR/.venv hazir"

# --- WorldPainter --------------------------------------------------------
if command -v wpscript >/dev/null 2>&1 || [[ -x "$INSTALL_DIR/wpscript" ]]; then
    echo "==> WorldPainter zaten kurulu, atlaniyor"
else
    echo "==> WorldPainter indiriliyor"
    TMP="$(mktemp -d)"
    trap 'rm -rf "$TMP"' EXIT

    CANDIDATES=()
    [[ -n "$INSTALLER_URL" ]] && CANDIDATES+=("$INSTALLER_URL")
    CANDIDATES+=(
        "https://www.worldpainter.net/files/worldpainter_${WP_VERSION}_amd64.deb"
        "https://www.worldpainter.net/files/worldpainter_${WP_VERSION}_linux.sh"
    )

    GOT=""
    for url in "${CANDIDATES[@]}"; do
        echo "    deneniyor: $url"
        if curl -fsSL --retry 2 -o "$TMP/wp-installer" "$url"; then
            GOT="$url"
            break
        fi
    done

    if [[ -z "$GOT" ]]; then
        cat >&2 <<EOF

WorldPainter indirilemedi. Indirme adresleri surumle degisiyor.

Yapilacak: https://www.worldpainter.net/ adresinden Linux kurulum dosyasinin
(.deb ya da .sh) baglantisini alin ve su sekilde calistirin:

  sudo $0 --installer-url <baglanti>

Ya da dosyayi elle indirip kurun; kurulum sonrasi wpscript'in yolunu
scripts/build_world.sh icinde --wpscript ile verebilirsiniz.
EOF
        exit 1
    fi

    if [[ "$GOT" == *.deb ]]; then
        echo "==> .deb kuruluyor"
        apt-get install -y -qq "$TMP/wp-installer" || dpkg -i "$TMP/wp-installer"
    else
        echo "==> install4j kurulumu (gozetimsiz)"
        chmod +x "$TMP/wp-installer"
        # install4j gozetimsiz mod: -q sessiz, -dir hedef dizin
        "$TMP/wp-installer" -q -dir "$INSTALL_DIR"
    fi
fi

WPSCRIPT="$(command -v wpscript || true)"
[[ -z "$WPSCRIPT" && -x "$INSTALL_DIR/wpscript" ]] && WPSCRIPT="$INSTALL_DIR/wpscript"

echo ""
echo "==> ozet"
echo "    python : $REPO_DIR/.venv/bin/python3"
echo "    java   : $(command -v java || echo 'bulunamadi')"
echo "    wpscript: ${WPSCRIPT:-bulunamadi}"
echo "    bellek : $(free -g | awk '/^Mem:/ {print $2}') GB"
echo ""
if [[ -z "$WPSCRIPT" ]]; then
    echo "wpscript bulunamadi; kurulum dizinini kontrol edin ($INSTALL_DIR)." >&2
    exit 1
fi
echo "Sirada: ./scripts/build_world.sh --source source/westeros.png --scale 16"
