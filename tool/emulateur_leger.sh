#!/usr/bin/env bash
# Émulateur léger de Fikajiana (ADR 0057) : image ATD sans applis ni interface système,
# 2 Go de RAM, 2 cœurs, sans fenêtre par défaut, priorité basse. Refuse de démarrer si l'ordinateur
# n'a pas assez de mémoire libre, pour ne pas le faire planter.
#
# Usage :
#   tool/emulateur_leger.sh creer              # une fois : télécharge l'image et crée l'AVD fikajiana_leger
#   tool/emulateur_leger.sh lancer [--fenetre] # démarre et attend la fin du démarrage
#   tool/emulateur_leger.sh arreter
#   tool/emulateur_leger.sh supprimer          # enlève l'AVD (l'image téléchargée reste)
set -euo pipefail

AVD=fikajiana_leger
IMAGE="system-images;android-35;aosp_atd;x86_64"
RAM_MO=2048          # minimum accepté par l'émulateur : 1536 Mo
COEURS=2
MARGE_MO=1536        # mémoire qui doit rester libre pour l'ordinateur en plus de RAM_MO

sdk=${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Android/Sdk}}
export ANDROID_SDK_ROOT=$sdk
outils="$sdk/cmdline-tools/latest/bin"
emulateur="$sdk/emulator/emulator"
adb="$sdk/platform-tools/adb"

serie_de_l_avd() {
  for serie in $("$adb" devices | awk '/^emulator-/ {print $1}'); do
    if [ "$("$adb" -s "$serie" emu avd name 2>/dev/null | head -1 | tr -d '\r')" = "$AVD" ]; then
      echo "$serie"
      return 0
    fi
  done
  return 1
}

creer() {
  yes | "$outils/sdkmanager" --install "emulator" "platform-tools" "$IMAGE" > /dev/null
  echo no | "$outils/avdmanager" create avd --force --name "$AVD" --package "$IMAGE" --device "pixel_5"
  config="$HOME/.android/avd/$AVD.avd/config.ini"
  # Réglages légers : petit écran (la tablette est simulée par wm size), pas de caméra, de son ni de capteurs inutiles.
  while IFS='=' read -r cle valeur; do
    sed -i "/^$cle *=/d" "$config"
    echo "$cle=$valeur" >> "$config"
  done <<'REGLAGES'
hw.ramSize=2048
hw.cpu.ncore=2
vm.heapSize=256
hw.lcd.width=720
hw.lcd.height=1600
hw.lcd.density=320
hw.gpu.enabled=yes
hw.gpu.mode=swiftshader_indirect
hw.audioInput=no
hw.audioOutput=no
hw.camera.back=none
hw.camera.front=none
hw.gps=no
hw.sensors.proximity=no
hw.keyboard=yes
disk.dataPartition.size=4G
fastboot.forceColdBoot=yes
REGLAGES
  echo "AVD $AVD créé ($IMAGE, ${RAM_MO} Mo, $COEURS cœurs)."
}

lancer() {
  if serie=$(serie_de_l_avd); then
    echo "Déjà lancé : $serie"
    return 0
  fi
  libre=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
  besoin=$((RAM_MO + MARGE_MO))
  if [ "$libre" -lt "$besoin" ]; then
    echo "Refusé : ${libre} Mo libres, il en faut ${besoin} (fermer des applis, ou baisser RAM_MO à 1536)." >&2
    exit 1
  fi
  fenetre=(-no-window)
  [ "${1:-}" = "--fenetre" ] && fenetre=()
  nice -n 10 "$emulateur" -avd "$AVD" "${fenetre[@]}" -memory "$RAM_MO" -cores "$COEURS" \
    -gpu swiftshader_indirect -no-audio -no-boot-anim -no-snapshot -camera-back none -camera-front none \
    > "/tmp/$AVD.log" 2>&1 &
  echo "Démarrage (journal : /tmp/$AVD.log)…"
  for _ in $(seq 1 180); do
    if serie=$(serie_de_l_avd) && [ "$("$adb" -s "$serie" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; then
      echo "Prêt : $serie (ANDROID_SERIAL=$serie)"
      return 0
    fi
    sleep 2
  done
  echo "Pas démarré en 6 min : voir /tmp/$AVD.log" >&2
  exit 1
}

arreter() {
  if serie=$(serie_de_l_avd); then
    "$adb" -s "$serie" emu kill
    echo "Arrêté : $serie"
  else
    echo "$AVD n'est pas lancé."
  fi
}

case "${1:-}" in
  creer) creer ;;
  lancer) lancer "${2:-}" ;;
  arreter) arreter ;;
  supprimer) "$outils/avdmanager" delete avd --name "$AVD" ;;
  *) sed -n '2,10p' "$0"; exit 2 ;;
esac
