# 0005 — Graphique et géométrie écrits en Dart

- **Date** : 2026-11-05 · **Statut** : accepté
- **Décision** : traceur 2D `CustomPainter` maison (échantillonnage adaptatif, asymptotes, marching squares pour
  l'implicite) ; noyau de géométrie dynamique maison en Dart pur (graphe de dépendances objets libres/construits).
- **Raison** : `fl_chart`/`graphic` ne tracent pas de fonctions ; code GeoGebra GPL mais nom et contenus réservés
  (https://www.geogebra.org/license) ; architecture inspirée de JSXGraph (MIT, https://github.com/jsxgraph/jsxgraph),
  sans copie.
- **3D** : différée (`flutter_scene` exige le canal master).
