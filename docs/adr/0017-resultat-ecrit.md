# 0017 — Résultat écrit à la main après le signe égal

- **Date** : 2026-11-06 · **Statut** : accepté (demande d'Antsa)
- **Décision** : quand l'écriture finit par `=`, le résultat se trace juste après, à la taille de l'écriture, en couleur d'accent : chiffres, lettres,
  fractions, puissances, racines. La carte reste dessous : ce qui a été compris y est lisible et corrigeable (ADR 0003).
- **Méthode** : alphabet de tracés dessiné pour Fikajiana (`lib/comprendre/ecriture_resultat.dart`), rendu comme un trait de stylet par `perfect_freehand`.
  Rien n'est repris d'une police ni d'une autre application. C'est une écriture générée, pas celle de l'utilisateur.
- **Limite** : ce que l'alphabet ne sait pas écrire (matrices, `\sin`, lettres absentes) reste sur la carte. Rien n'est inventé.
- **Plus tard** : imiter l'écriture de l'utilisateur, à partir de ses propres chiffres. Non étudié.
