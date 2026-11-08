# ADR 0039 — L'app de collecte, à part de Fikajiana

- **Date** : 2026-11-08 · **Statut** : remplacé par l'ADR 0042 (app retirée du dépôt le 2026-11-08, à la demande d'Antsa : Fikajiana recueille elle-même l'écriture)
- **Décision** : une petite app Flutter séparée, `collecte/app/`, paquet `mg.fikajiana.collecte`, nom « Fikajiana Écriture ». Elle n'installe ni ne modifie Fikajiana et ne dépend pas de son code.
- **Données** : format `collecte/FORMAT.md`. Signes lus dans `collecte/classes.txt` et expressions dans `collecte/expressions.txt`, par des liens symboliques dans `assets/` (pas de copie à la main ; un test vérifie que le contenu est identique).
- **Un raté** est enregistré (`rejete: true`) et le même signe est redemandé : le compteur n'avance pas.
- **Sans réseau** : aucune permission dans le manifeste (vérifié par `aapt2 dump permissions`). Partage par `Intent.ACTION_SEND` et `FileProvider` dans `MainActivity.kt`, sans plugin (pas de `share_plus` ni `path_provider` : plus léger). Séances écrites dans `getExternalFilesDir(null)/seances/`, lisible par `adb pull`.
- **Signature** : même clé que Fikajiana (`release-keys/`, hors Git). minSdk 26 pour une icône seulement adaptative.
- **Publication** : release GitHub à part, `collecte-vX.Y.Z`, en pré-version, pour ne pas changer le lien « dernière version » que suit la mise à jour de Fikajiana (ADR 0015).
