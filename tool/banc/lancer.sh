#!/usr/bin/env bash
# Lance le banc de calcul sur un appareil (ANDROID_SERIAL) et affiche ses lignes.
# Il s'installe à côté de l'app (mg.fikajiana.app.banc), sur l'écran secondaire s'il y en a un.
# Usage : tool/banc/lancer.sh [android-x64|android-arm64]
set -euo pipefail
cible=${1:-android-x64}
cd "$(dirname "$0")/../../app"
flutter build apk --release --target-platform "$cible" --split-per-abi --android-project-arg banc=1 -t banc/banc_calcul.dart | tail -1
case "$cible" in
  android-x64) apk=app-x86_64-release.apk ;;
  *) apk=app-arm64-v8a-release.apk ;;
esac
adb install -r "build/app/outputs/flutter-apk/$apk" | tail -1
paquet=mg.fikajiana.app.banc
adb shell am force-stop "$paquet"
# Un autre essai peut occuper l'écran principal : ne pas lui voler la main.
ecran=$(adb shell dumpsys display | sed -n 's/.*mDisplayId=\([1-9][0-9]*\).*/\1/p' | head -1)
depart=$(adb shell date '+%m-%d\ %H:%M:%S.000')
adb shell am start ${ecran:+--display "$ecran"} -n "$paquet/mg.fikajiana.app.MainActivity" > /dev/null
lire() { adb logcat -d -T "$depart" -v raw -s flutter:I | grep 'BANC' || true; }
for _ in $(seq 1 250); do
  if lire | grep -q 'BANC FIN'; then break; fi
  sleep 2
done
lire
adb shell am force-stop "$paquet"
