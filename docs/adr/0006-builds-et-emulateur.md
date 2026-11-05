# 0006 — Constructions et essais

- **Date** : 2026-11-05 · **Statut** : accepté
- **Contexte** : le conteneur cloud n'atteint pas dl.google.com (SDK Android) et l'ordinateur d'Antsa n'expose aucun
  dossier Remote Control ce jour.
- **Décision** : APK construit par **GitHub Actions** ; essais sur émulateur en CI (profils `pixel_7` et `pixel_tablet`), captures publiées en artefact ; sur l'ordinateur d'Antsa, AVD
  « Resizable » (https://developer.android.com/studio/run/resizable-emulator) dès qu'il est accessible.
- **Ajout du 2026-11-05** : AVD local `fikajiana_resizable` (profil `resizable`, Android 36), lancé avec
  `-gpu swiftshader_indirect` ; formes simulées par `wm size` / `wm density` (téléphone 1080×2400 à 420, tablette
  1600×2560 à 320).
  La tablette 800×1340 à 280 d'abord prévue ne faisait que 457 dp de large (800 × 160 / 280), sous le seuil de 600 dp.
- **APK de CI** : release arm64 et x86_64 signés avec la clé de débogage faute de clé, donc non diffusables.
