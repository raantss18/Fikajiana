# 0013 — Rendu du trait et formes au maintien

- **Date** : 2026-11-06 · **Statut** : accepté, à régler au vrai stylet
- **Décision** : le trait affiché passe par le filtre 1€ (https://gery.casiez.net/1euro/) puis `perfect_freehand` (MIT), avec la pression du stylet.
  **Les points bruts sont gardés à part** : la reconnaissance ne lit qu'eux, jamais le trait lissé.
- **Formes** : stylet maintenu 450 ms à la fin d'un trait → ligne (redressée près des axes), cercle, triangle ou rectangle. S'annule. Sinon le trait reste libre.
- **Méthode** : géométrie seule, sans modèle : moindres carrés de Kåsa, Ramer-Douglas-Peucker (https://en.wikipedia.org/wiki/Ramer%E2%80%93Douglas%E2%80%93Peucker_algorithm).
- **Non retenu** : correction automatique de l'écriture en continu (`docs/recherche/ambition.md`) ; `one_dollar_unistroke_recognizer`, dépendance inutile pour ces quatre formes.
- **À vérifier** : formule du filtre recopiée de mémoire et contrôlée par un calcul à la main, pas sur l'article ni le code de référence ; seuils et réglages choisis sans vrai stylet.
