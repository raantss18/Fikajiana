#!/usr/bin/env bash
# Construit les APK release, puis les essaie sur l'émulateur lancé, en téléphone et en tablette.
# Usage : tool/essai_local.sh
set -euo pipefail

racine=$(cd "$(dirname "$0")/.." && pwd)
apks="$racine/app/build/app/outputs/flutter-apk"
sortie="$racine/app/build/captures"

(cd "$racine/app" && flutter build apk --release --split-per-abi --target-platform android-arm64,android-x64)

# Seul l'émulateur de Fikajiana : les autres projets peuvent en avoir un en cours d'usage.
emulateur=""
for serie in $(adb devices | awk '/^emulator-/ {print $1}'); do
  case "$(adb -s "$serie" emu avd name | head -1 | tr -d '\r')" in
    fikajiana_leger|fikajiana_resizable) emulateur=$serie ;;
  esac
done
if [ -z "$emulateur" ]; then
  echo "Aucun émulateur de Fikajiana n'est lancé :" >&2
  echo "  tool/emulateur_leger.sh lancer   (après tool/emulateur_leger.sh creer, une fois)" >&2
  exit 1
fi
export ANDROID_SERIAL=$emulateur
trap 'adb shell wm size reset; adb shell wm density reset' EXIT

essayer() {
  adb shell wm size "$2"
  adb shell wm density "$3"
  "$racine/tool/essai_appareil.sh" "$apks/app-x86_64-release.apk" "$sortie" "$1"
}

essayer telephone 1080x2400 420
essayer tablette 1600x2560 320

echo "APK : $apks"
echo "Captures : $sortie"
