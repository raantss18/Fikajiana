# 0015 — Mises à jour dans l'application

- **Date** : 2026-11-06 · **Statut** : accepté (demande d'Antsa), à mettre en œuvre (TODO P1)
- **Décision** : Réglages → Mises à jour, comme COMIMa et zanakiantsa : `release.json` au format figé, signature Ed25519, APK vérifié par
  son SHA-256, puis même clé de signature Android exigée par l'installateur.
- **Hors ligne** : seule exception au « 100 % hors ligne », et **à la demande** : la recherche part d'un bouton, rien n'est envoyé hors de la
  requête elle-même, et sans réseau tout le reste marche. Aucune vérification automatique pour l'instant.
- **Publication** : seul Antsa décide d'une version publique. Distribution par APK direct ; une version Play devrait retirer ce mécanisme
  (https://support.google.com/googleplay/android-developer/answer/9888379, cité par l'ADR 0011 de zanakiantsa, non rouvert ici).
