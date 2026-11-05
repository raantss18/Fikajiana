# 0008 — Appareils de test

- **Date** : 2026-11-05 · **Statut** : accepté (Antsa)
- **Décision** : **Xiaomi Pad 7 avec stylet** (tablette, essais d'écriture au stylet) et **Poco F8 Pro** (téléphone,
  essais au doigt). Émulateurs en complément (ADR 0006), qui ne remplacent pas la mesure sur appareil réel.
- **Non vérifié** : fiche technique des deux appareils (écran, densité, RAM, version Android) ; à relever par
  `adb shell getprop`, `wm size`, `wm density` au premier branchement, puis à noter ici.
- **Réseau** : environnement cloud « Fikajiana » créé (huggingface.co et dl.google.com autorisés, 2026-11-05).
