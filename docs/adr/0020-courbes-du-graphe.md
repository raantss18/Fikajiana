# ADR 0020 — Courbes implicites, paramétrées et polaires

- **Date** : 2026-11-06 · **Statut** : accepté, à mesurer sur un appareil réel
- **Décision** : le Graphe lit aussi `x^2+y^2=4` et `x=3`, `(\cos(t),\sin(t))` ou `x=…,y=…` avec un domaine facultatif `, t \in [a,b]`, et `r=1+\cos(\theta)`. Tout reste en Dart pur, sans dépendance.
- **Implicites** : grille de 8 pixels, mailles traversées affinées deux fois, puis carrés marchants (https://en.wikipedia.org/wiki/Marching_squares). Un pôle est écarté : la fonction y reste grande au point de croisement.
- **Paramétrées et polaires** : points ajoutés là où la courbe tourne, coupure là où elle n'existe pas ou saute. Par défaut, t va de -10 à 10 et θ de 0 à 4π.
- **Outils** : le Graphe passe à une liste de commandes nommées, comme la Géométrie (ADR 0019). Tableau de valeurs : fonctions de x seulement, 21 lignes.
- **Limites** : une courbe où la fonction s'annule sans changer de signe, comme `(x-y)^2=0`, n'est pas vue. Pas de tracé garanti façon Tupper (TODO P4.3). `(1,2)` reste le nombre 1,2 : la virgule est décimale. Depuis la Feuille, seules les fonctions ont le bouton Tracer.
- **Mesuré** : sur l'ordinateur, 0,7 ms pour un cercle et 19 ms pour `sin(xy)=0`, le pire cas essayé, par tracé. Rien sur un téléphone : chaque image recalcule ses courbes.
- **Références** : SymPy 1.14 pour la cardioïde et Lissajous ; longueurs 4π et 8 pour le cercle et la cycloïde.
