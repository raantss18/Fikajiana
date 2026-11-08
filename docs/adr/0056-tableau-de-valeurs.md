# ADR 0056 — Tableau de valeurs sur la Feuille

- **Date** : 2026-11-09 · **Statut** : accepté (vague 4 de `docs/recherche/couverture-calcul.md`)
- **Décision** : `tableau(f;début;fin;pas)` (pas 1 par défaut), pour une fonction définie plus haut ou une expression en x, rend une matrice de deux lignes : x, puis f(x), valeurs exactes, écrites à la main comme les autres matrices. Au plus 21 colonnes (au-delà, la ligne déborde d'un téléphone).
- **Calcul** : les x se calculent côté Dart (nombres écrits, gardés exacts : 1/2 plutôt que 0,5) ; Giac calcule chaque f(x), comme `f(2)=`. On n'utilise pas `tablefunc`, qui remplit le tableur de Xcas (doc Giac cascmd_fr301).
- **Saisie** : à la main (`tableau` reconnu à sa silhouette, sans gêner les feuilles d'Antsa) et au clavier.
- **Vérifié** : voir `docs/TODO.md`.
