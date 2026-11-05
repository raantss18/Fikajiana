#!/usr/bin/env bash
# Prépare une version signée (ADR 0015) dans release-out/ : APK arm64, release.json, release.json.sig.
# Usage : tool/release.sh "Message en français" "Message in English"
# La publication sur GitHub se fait ensuite, seulement sur décision d'Antsa (docs/RELEASING.md).
set -euo pipefail

fr=${1:?message en français}
en=${2:?message in English}
racine=$(cd "$(dirname "$0")/.." && pwd)
cles="$racine/release-keys"
[ -f "$cles/ed25519.pem" ] || { echo "Clé absente : $cles/ed25519.pem" >&2; exit 1; }
[ -f "$racine/app/android/key.properties" ] || { echo "app/android/key.properties absent" >&2; exit 1; }
[ -f "$racine/native/giac/construit/jniLibs/arm64-v8a/libfikajiana_giac.so" ] || {
  echo "Giac absent : lancer native/giac/construire.sh arm64-v8a" >&2; exit 1; }

cd "$racine/app"
version=$(sed -n 's/^version: *\([^+]*\).*/\1/p' pubspec.yaml)
flutter build apk --release --split-per-abi --target-platform android-arm64
apk=build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
aapt2=$(ls -d "$HOME"/Android/Sdk/build-tools/*/aapt2 | tail -1)
# Flutter ajoute 2000 au versionCode pour arm64 : c'est lui que l'app compare.
build=$("$aapt2" dump badging "$apk" | sed -n "s/.*versionCode='\([0-9]*\)'.*/\1/p")

out="$racine/release-out"
mkdir -p "$out"
nom="fikajiana-$version-arm64-v8a.apk"
cp "$apk" "$out/$nom"
sha=$(sha256sum "$out/$nom" | cut -d' ' -f1)
octets=$(stat -c %s "$out/$nom")
url="https://github.com/raantss18/Fikajiana/releases/download/app-v$version/$nom"
python3 -I - "$out/release.json" "$build" "$version" "$fr" "$en" "$url" "$sha" "$octets" <<'PY'
import json, sys
chemin, build, version, fr, en, url, sha, octets = sys.argv[1:]
json.dump({"format": 1, "latest": {"build": int(build), "version": version, "notes": {"fr": fr, "en": en},
           "apk": {"url": url, "sha256": sha, "bytes": int(octets)}}},
          open(chemin, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
openssl pkeyutl -sign -inkey "$cles/ed25519.pem" -rawin -in "$out/release.json" | base64 -w0 > "$out/release.json.sig"
echo "Prêt dans $out : $nom (build $build, $octets octets), release.json, release.json.sig"
