#!/usr/bin/env bash
# Lance le banc de calcul sur un appareil (ANDROID_SERIAL) et affiche ses lignes.
# Il s'installe à côté de l'app (mg.fikajiana.app.banc), sur l'écran secondaire s'il y en a un.
# Usage : tool/banc/lancer.sh [android-x64|android-arm64] [banc/banc_calcul.dart|banc/banc_lecture.dart]
set -euo pipefail
cible=${1:-android-x64}
banc=${2:-banc/banc_calcul.dart}
cd "$(dirname "$0")/../../app"
flutter build apk --release --target-platform "$cible" --split-per-abi --android-project-arg banc=1 -t "$banc" | tail -1
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
lire() { adb logcat -d -T "$depart" -v raw -s flutter:I | command grep -a 'BANC' || true; }
# Un cas qui ne rend pas la main se voit : plus rien ne s'écrit pendant 60 s.
avant=-1
immobile=0
while [ "$immobile" -lt 30 ]; do
  sortie=$(lire)
  if printf '%s' "$sortie" | command grep -aq 'BANC FIN'; then break; fi
  nombre=$(printf '%s' "$sortie" | wc -l)
  if [ "$nombre" = "$avant" ]; then immobile=$((immobile + 1)); else immobile=0; fi
  avant=$nombre
  python3 -c 'import time; time.sleep(2)'
done
lire | command grep -av 'BANC CAS' || true
if [ "$immobile" -ge 30 ]; then
  echo "BANC BLOQUE sur : $(lire | tail -1)"
fi
adb shell am force-stop "$paquet"
