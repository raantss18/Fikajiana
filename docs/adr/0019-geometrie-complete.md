# ADR 0019 — Géométrie : outils nommés, moteur étendu, documents multiples

**Contexte.** Antsa (0.3.0, Poco) : la Géométrie « n'est pas claire et incomplète », un `=` ne dit pas « parallèle » ; créer un nouveau document n'est pas évident.

**Décision.**
1. Chaque outil porte son nom en toutes lettres et un dessin propre au projet : ce qu'on touche en sombre, ce qu'on obtient en couleur. Une barre dit l'outil, l'étape et ce qu'il attend.
2. Le moteur reste en Dart pur (`fikajiana_math`) : arcs, demi-droites, vecteurs, polygones, coniques, transformations, mesures, curseurs, lieux.
3. Un toucher est interprété : point proche, puis croisement, puis point sur objet, puis grille. Glisser construit aussi, avec un aperçu.
4. « Relation » dit ce qui est vrai ici, puis déforme la figure 24 fois au hasard. C'est un indice fort, **pas une démonstration**, et l'app le dit.
5. Graphes et figures sont plusieurs fichiers (`Classeur`), comme les feuilles. Le Menu crée, l'Historique rouvre. L'ancien fichier est repris sans perte.

**Limites connues.** Pas encore : texte libre, trace d'un point, fonctions dans la figure, saisie d'équations, formes dessinées reconnues. Un contact tangent entre deux coniques n'est pas vu (recherche par changement de signe).

**Conséquences.** Références croisées avec SymPy 1.14 dans `geometrie_test.dart`. Règle 7 : aucune icône ni aucun texte repris d'une app existante.
