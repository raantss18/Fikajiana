# Publier une version (ADR 0015)

Procédure commune à COMIMa, zanakiantsa et academik. Une version sort après chaque modification majeure ou plusieurs améliorations (demande d'Antsa, 2026-11-06).

1. `app/pubspec.yaml` : `version: x.y.z+n`, `n` toujours croissant.
2. `app/CHANGELOG.md` : renommer `## [Non publié]`, écrire `### Message fr` et `### Message en` : 2 à 4 lignes sur **ce que la version permet
   de faire**, jamais le journal technique.
3. Analyse et tests, puis `tool/release.sh "message fr" "message en"` : dans `release-out/`, l'APK (nom versionné **et** nom stable), `release.json`, `release.json.sig`, `SHA256SUMS.txt`, et `notes.md`, la fiche de téléchargement tirée du CHANGELOG. Giac doit être compilé (`native/giac/construire.sh arm64-v8a`), et `app/android/key.properties` présent.
4. Si le calcul ou sa lecture ont changé : `tool/banc/lancer.sh`, qui doit finir par `BANC FIN : n/n`, avec `android-arm64` sur un appareil réel.
5. Essai sur appareil arm64 réel, **par-dessus la version précédente** : la feuille doit être conservée. Essai réseau coupé.
6. Publication : `cd release-out && gh release create app-vX.Y.Z fikajiana-*.apk release.json release.json.sig SHA256SUMS.txt --title "Fikajiana X.Y.Z" --notes-file notes.md`.
   L'app lit `https://github.com/raantss18/Fikajiana/releases/latest/download/release.json` : pas de préversion pour une version à proposer.

Clés, jamais dans Git, à sauvegarder ailleurs : `release-keys/`. **Les perdre empêche toute mise à jour des apps installées.**
