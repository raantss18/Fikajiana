#!/usr/bin/env bash
# Télécharge les polices manuscrites OFL de l'entraînement, avec leur licence.
# Source : https://github.com/google/fonts, figé à un commit (voir entrainement/SOURCES.md).
# Usage : bash entrainement/recuperer_polices.sh   (écrit dans entrainement/polices/, hors Git)
set -euo pipefail

COMMIT=86aced91de05cd4f96a06838124cca45be337b2b
BASE="https://raw.githubusercontent.com/google/fonts/$COMMIT/ofl"
ICI="$(cd "$(dirname "$0")" && pwd)"
DEST="$ICI/polices"
mkdir -p "$DEST"

# dossier  fichier
POLICES=(
  "caveat Caveat[wght].ttf"
  "patrickhand PatrickHand-Regular.ttf"
  "kalam Kalam-Regular.ttf"
  "kleeone KleeOne-Regular.ttf"
  "yomogi Yomogi-Regular.ttf"
  "zenkurenaido ZenKurenaido-Regular.ttf"
)

for ligne in "${POLICES[@]}"; do
  read -r dossier fichier <<<"$ligne"
  mkdir -p "$DEST/$dossier"
  if [[ ! -s "$DEST/$dossier/$fichier" ]]; then
    curl -fsSL "$BASE/$dossier/$(printf %s "$fichier" | sed "s/\[/%5B/; s/\]/%5D/")" -o "$DEST/$dossier/$fichier.part"
    mv "$DEST/$dossier/$fichier.part" "$DEST/$dossier/$fichier"
  fi
  [[ -s "$DEST/$dossier/OFL.txt" ]] || curl -fsSL "$BASE/$dossier/OFL.txt" -o "$DEST/$dossier/OFL.txt"
done

# Empreintes : comparées à entrainement/polices.sha256 si présent.
cd "$DEST"
if [[ -f "$ICI/polices.sha256" ]]; then
  sha256sum -c "$ICI/polices.sha256"
else
  sha256sum */*.ttf */OFL.txt
fi
