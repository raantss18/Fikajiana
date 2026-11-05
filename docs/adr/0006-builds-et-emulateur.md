# 0006 — Constructions et essais

- **Date** : 2026-11-05 · **Statut** : accepté
- **Contexte** : le conteneur cloud n'atteint pas dl.google.com (SDK Android) et l'ordinateur d'Antsa n'expose aucun
  dossier Remote Control ce jour.
- **Décision** : APK construit par **GitHub Actions** ; essais sur émulateur en CI (AVD téléphone 1080×2400 et tablette
  800×1340 densité 280, comme zanakiantsa), captures publiées en artefact ; sur l'ordinateur d'Antsa, AVD
  « Resizable » (https://developer.android.com/studio/run/resizable-emulator) dès qu'il est accessible.
