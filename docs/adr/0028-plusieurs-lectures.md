# ADR 0028 — Plusieurs lectures, seulement dans le doute

- **Date** : 2026-11-07 · **Statut** : accepté (choix d'Antsa), à mesurer sur le Pad 7
- **Pourquoi** : aucun modèle libre aux poids propres ne bat nettement Pix2Text (`docs/recherche/modele-manuscrit.md`) ; sur 50 expressions, la bonne lecture est dans le top 3 de la recherche en faisceau 41 fois, contre 36 en lecture simple.
- **Décision** : lecture simple d'abord. Si `plausibilite` s'étonne, recherche en faisceau de largeur 3, choix de la plus plausible selon les maths et les fonctions de la feuille. Les autres sont proposées au panneau.
- **Coût** : environ 3 fois le décodage, payé seulement dans le doute ; 96 jetons au plus. Budget : 500 ms pour une expression courte, 1 s pour une longue.
- **Refusé** : poids entraînés sur des données non commerciales.
- **Corpus** : 200 lignes d'Antsa, publiques en CC0, pour mesurer sans se mentir.
- **Limite** : une lecture fausse mais plausible (`x+1` lu `x+7`) ne déclenche rien. Le score ne dit pas qu'une lecture est juste.
