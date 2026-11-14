# ADR 0060 — Banc d'essai Linux, sans appareil ni émulateur

- **Date** : 2026-11-14 · **Statut** : accepté (Antsa : « tu peux créer un petit émulateur pour le test »)
- **Contexte** : les sessions cloud n'ont pas de virtualisation (pas de `/dev/kvm`) : l'émulateur Android, même léger
  (ADR 0057), n'y démarre pas.
- **Décision** : `tool/banc_linux.sh` compile Giac pour l'hôte (commit et correctifs de l'app) et la **vraie app** pour
  Linux, la lance dans un écran virtuel Xvfb (tablette 1280×800, téléphone 412×915), pilotée par `xdotool`, capturée
  par `import` ou filmée par `ffmpeg`.
- **Vérifié** (2026-11-14, session cloud) : l'app s'ouvre ; `z^2-2z+5=0` tapé donne `⇔ z=1+2i or z=1−2i`, écrit à la
  main (`docs/captures/banc-linux-complexes.png`) : clavier → lecteur → Giac → affichage, de bout en bout.
- **Limites** : x86_64 et non arm64 ; souris et non stylet (pas de pression) ; GTK et non Android (permissions,
  partage, mise à jour, cycle de vie non couverts). Ne remplace pas l'essai sur le Pad 7 (règle 4).
- **Reste à tester** : lecture de l'écriture (modèle ONNX absent du dépôt : à télécharger), format téléphone.
