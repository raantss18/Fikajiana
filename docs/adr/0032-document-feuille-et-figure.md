# ADR 0032 — Un document : une feuille et sa Figure

- **Date** : 2026-11-07 · **Statut** : accepté
- **Constat** (Antsa, Pad 7) : « beaucoup de confusion entre ancienne feuille et nouvelle ainsi que la figure ». Feuilles, graphes et figures étaient trois classeurs séparés : une nouvelle feuille gardait la Figure de l'ancienne, l'Historique avait trois listes.
- **Décision** : un document = `feuilles/<id>.json` + `graphes/<id>.json` + `figures/<id>.json`, sous un même `id`. Le Carnet est seul maître : la Figure suit `carnet.courante`. Nouvelle feuille = nouvelle Figure vide (demande d'Antsa) ; ouvrir, supprimer agissent sur les deux. L'Historique n'a plus qu'une liste, « Documents », chacun avec ce que contient sa Figure.
- **Migration** (une fois, marque `documents.txt` = 2) : chaque figure ou graphe d'avant rejoint la feuille dont il reprend le contenu (mêmes points, même courbe) ; sans ressemblance, il reste un document à part. Rien ne se perd.
- **Page** : la feuille s'arrête en haut et à gauche (sauf encre d'avant), trois écrans de large ; l'export PNG/PDF part de son coin.
- **Vérifié** : tests `carnet_test` (dont le cas réel du Pad 7) ; sur le Pad 7, figure et courbe revenues à leurs feuilles. **Reste** : nommer un document.
