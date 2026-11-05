# 0008 — Appareils de test

- **Date** : 2026-11-05 · **Statut** : accepté (Antsa)
- **Décision** : **Xiaomi Pad 7 avec stylet** (tablette, essais d'écriture au stylet) et **Poco F8 Pro** (téléphone,
  essais au doigt). Émulateurs en complément (ADR 0006), qui ne remplacent pas la mesure sur appareil réel.
- **Xiaomi Pad 7, mesuré par `adb` le 2026-11-05** : modèle 2410CRP4CG (`uke`), SoC SM7675, arm64-v8a seul, Android 16 (API 36),
  `OS3.0.304.0.WOZMIXM`, écran 2136×3200 à 440, RAM totale 7,3 Gio, pages de 4 Ko, stylet « Xiaomi Focus Pen » vu par Android.
- **Poco F8 Pro** : fiche non vérifiée, pas de câble ; à relever dans le rapport de l'écran d'essai.
- **Leçon** : un émulateur ne remplace pas l'arm64 réel, même avec l'APK arm64 traduit (`docs/recherche/spike-giac.md`).
- **Réseau** : environnement cloud « Fikajiana » créé (huggingface.co et dl.google.com autorisés, 2026-11-05).
