# 0006 — Constructions et essais

- **Date** : 2026-11-05 (révisé le même jour) · **Statut** : accepté (Antsa : « tout en local »)
- **Contexte** : le projet ne dépend plus du conteneur cloud, qui n'atteignait pas dl.google.com ; le SDK Android, le NDK
  et les appareils sont sur l'ordinateur d'Antsa.
- **Décision** : APK et essais **en local** : `tool/essai_local.sh` (APK release arm64 + x86_64, puis émulateur en
  téléphone et tablette) et `tool/essai_appareil.sh` (appareil réel). GitHub Actions ne fait que l'analyse et les tests.
- **Émulateur** : AVD `fikajiana_resizable` (https://developer.android.com/studio/run/resizable-emulator), lancé avec
  `-gpu swiftshader_indirect` : gfxstream a fait planter l'émulateur sur cet ordinateur le 2026-11-03. Formes par
  `wm size` / `wm density` : téléphone 1080×2400 à 420, tablette 1600×2560 à 320 (800 dp, au-dessus du seuil de 600 dp).
- **Conséquences** : pas d'APK de machine neutre, à rediscuter avant toute diffusion publique. Sans clé, l'APK release
  est signé avec la clé de débogage, donc non diffusable.
