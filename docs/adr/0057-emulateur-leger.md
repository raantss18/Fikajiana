# ADR 0057 — Émulateur léger

- **Date** : 2026-11-14 · **Statut** : accepté (Antsa : « crée un émulateur assez léger pour que l'ordi ne plante pas »,
  loin de l'ordinateur, sans tablette branchée). Révise la règle « pas d'émulateur » du 2026-11-08 (`CLAUDE.md` § 4).
- **Décision** : AVD `fikajiana_leger` (`tool/emulateur_leger.sh`) : image **ATD** `aosp_atd` API 35 x86_64, 2048 Mo,
  2 cœurs, sans fenêtre, sans son ni caméra, rendu logiciel `swiftshader_indirect`, priorité basse (`nice`) ; refus de
  démarrer s'il reste moins de RAM + 1,5 Go libres. Écran 720×1600 ; téléphone et tablette par `wm size` (`essai_local.sh`).
- **Vérifié** : les ATD retirent applis, SystemUI et services inutiles pour réduire CPU et mémoire, sans rendu matériel
  (https://developer.android.com/studio/test/gradle-managed-devices) ; images `aosp_atd` x86_64 API 30 à 36
  (https://dl.google.com/android/repository/sys-img/aosp_atd/sys-img2-3.xml) ; `-memory` de 1536 à 8192 Mo, `-no-window`
  (https://developer.android.com/studio/run/emulator-commandline).
- **Limites** : pas d'arm64 (Giac y a déjà caché un défaut, ADR 0008) ; pas de stylet ; pas de barres système. L'essai
  sur le Pad 7 reste obligatoire avant de dire « fini ».
- **Reste à tester** : création et démarrage sur l'ordinateur d'Antsa, mémoire réelle (`free -m`), lecture d'une expression.
