#!/usr/bin/env bash
# Banc d'essai sans appareil ni émulateur (ADR 0060) : la vraie app compilée pour Linux, avec Giac compilé pour
# l'hôte au commit de l'app, dans un écran virtuel (Xvfb) qu'on pilote (xdotool) et qu'on capture (import, ffmpeg).
# Pour les machines sans virtualisation (pas de /dev/kvm), comme les sessions cloud.
#
# Usage :
#   tool/banc_linux.sh construire            # Giac pour l'hôte + app Linux (long la première fois)
#   tool/banc_linux.sh lancer [LxH]          # écran virtuel :99, tablette 1280x800 par défaut ; téléphone : 412x915
#   tool/banc_linux.sh capture <fichier.png>
#   tool/banc_linux.sh arreter
# Paquets : libgtk-3-dev clang pkg-config ninja-build cmake libgmp-dev libmpfr-dev xvfb xdotool imagemagick
set -euo pipefail

racine=$(cd "$(dirname "$0")/.." && pwd)
hote="$racine/native/giac/construit/hote"
paquet="$racine/app/build/linux/x64/release/bundle"
giac_commit=19a710aea9d528afa272ea582f3283f242e17af3
export DISPLAY=${DISPLAY:-:99}

construire() {
  sources="$racine/native/giac/sources/giac"
  if [ ! -d "$sources" ]; then
    git clone --depth 50 https://github.com/geogebra/giac.git "$sources"
    git -C "$sources" fetch --depth 1 origin "$giac_commit"
    git -C "$sources" checkout -q "$giac_commit"
  fi
  [ "$(git -C "$sources" rev-parse HEAD)" = "$giac_commit" ] || { echo "Giac n'est pas au commit $giac_commit" >&2; exit 1; }
  for correctif in "$racine"/native/giac/correctifs/*.patch; do
    if git -C "$sources" apply --check "$correctif" 2> /dev/null; then git -C "$sources" apply "$correctif"; fi
  done
  mkdir -p "$hote"
  # Le CMakeLists d'Android, lié à GMP et MPFR du système ; -fpermissive : la libstdc++ de l'hôte le demande.
  sed -e 's#\${PREFIXE}/lib/libmpfr.a \${PREFIXE}/lib/libgmp.a log#mpfr gmp#' \
      -e 's#-Wl,-z,max-page-size=16384##' \
      -e "s#fikajiana_giac.cc#$racine/native/giac/fikajiana_giac.cc#" \
      -e 's#-fno-strict-aliasing -fPIC -w#-fno-strict-aliasing -fPIC -w -fpermissive#' \
      "$racine/native/giac/CMakeLists.txt" > "$hote/CMakeLists.txt"
  cmake -S "$hote" -B "$hote/build" -G Ninja -DCMAKE_BUILD_TYPE=Release -DPREFIXE=/usr -DGIAC_SOURCES_DIR="$sources"
  cmake --build "$hote/build" -j "$(nproc)"
  (cd "$racine/app" && flutter build linux --release)
  cp "$hote/build/libfikajiana_giac.so" "$paquet/lib/"
  echo "Prêt : $paquet/fikajiana"
}

lancer() {
  taille=${1:-1280x800}
  arreter > /dev/null 2>&1 || true
  Xvfb "$DISPLAY" -screen 0 "${taille}x24" > /dev/null 2>&1 &
  for _ in $(seq 1 20); do xdotool getdisplaygeometry > /dev/null 2>&1 && break; sleep 0.5; done
  LIBGL_ALWAYS_SOFTWARE=1 "$paquet/fikajiana" > /tmp/fikajiana_banc.log 2>&1 &
  for _ in $(seq 1 60); do
    if xdotool search --name Fikajiana > /dev/null 2>&1; then echo "Lancé sur $DISPLAY ($taille)"; return 0; fi
    sleep 0.5
  done
  echo "L'app ne s'est pas ouverte : voir /tmp/fikajiana_banc.log" >&2
  exit 1
}

arreter() {
  pkill -x fikajiana || true
  pkill -x Xvfb || true
}

case "${1:-}" in
  construire) construire ;;
  lancer) lancer "${2:-}" ;;
  capture) import -window root "${2:?fichier.png}" ;;
  arreter) arreter ;;
  *) sed -n '2,11p' "$0"; exit 2 ;;
esac
