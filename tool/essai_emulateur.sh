#!/usr/bin/env bash
# Installe l'APK, le lance en portrait et paysage, clair et sombre, et garde une capture de chaque essai.
# Usage : tool/essai_emulateur.sh <apk> <dossier de sortie> <nom de la forme>
set -euo pipefail

apk=$1
sortie=$2
forme=$3
paquet=mg.fikajiana.app

mkdir -p "$sortie"
adb install -r "$apk"
adb shell cmd locale set-app-locales "$paquet" --locales fr
adb shell settings put system accelerometer_rotation 0

for rotation in 0 1; do
  for nuit in no yes; do
    orientation=$([ "$rotation" = 0 ] && echo portrait || echo paysage)
    theme=$([ "$nuit" = no ] && echo clair || echo sombre)
    nom="${forme}_${orientation}_${theme}"

    adb shell settings put system user_rotation "$rotation"
    adb shell cmd uimode night "$nuit" > /dev/null
    adb shell am force-stop "$paquet"
    adb logcat -c
    adb shell am start -W -n "$paquet/.MainActivity" > /dev/null
    sleep 8

    adb shell screencap -p /sdcard/capture.png
    adb pull /sdcard/capture.png "$sortie/$nom.png" > /dev/null

    adb shell uiautomator dump /sdcard/arbre.xml > /dev/null
    if ! adb exec-out cat /sdcard/arbre.xml | grep -q 'content-desc="Feuille"'; then
      echo "ÉCHEC $nom : titre « Feuille » introuvable" >&2
      exit 1
    fi
    # Seul le journal de l'application compte : les services du système y écrivent aussi leurs plantages.
    if ! pid=$(adb shell pidof "$paquet"); then
      echo "ÉCHEC $nom : l'application ne tourne plus" >&2
      exit 1
    fi
    if adb logcat -d --pid="$pid" | grep -E 'FATAL EXCEPTION|flutter.*(Exception|Error)'; then
      echo "ÉCHEC $nom : erreur dans le journal" >&2
      exit 1
    fi
    echo "OK $nom"
  done
done
