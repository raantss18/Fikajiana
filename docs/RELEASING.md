# Publier une version (ADR 0015)

Procédure commune à COMIMa, zanakiantsa et academik. **Seul Antsa décide d'une publication.** Pas encore en place : TODO P1.

1. `app/pubspec.yaml` : `version: x.y.z+n`, `n` toujours croissant.
2. `app/CHANGELOG.md` : renommer `## [Non publié]`, écrire `### Message fr` et `### Message en` : 2 à 4 lignes sur **ce que la version permet
   de faire**, jamais le journal technique.
3. Analyse et tests, puis `tool/release.sh` : APK arm64, `release.json`, `release.json.sig` dans `release-out/`.
4. Essai sur appareil arm64 réel, **par-dessus la version précédente** : la feuille doit être conservée. Essai réseau coupé.
5. Publication, action publique, avec l'accord d'Antsa : release GitHub portant ces fichiers.

Clés, jamais dans Git, à sauvegarder ailleurs : `release-keys/`. **Les perdre empêche toute mise à jour des apps installées.**
