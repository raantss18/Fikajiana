# ADR 0033 — Écriture au propre, main levée et noms

- **Date** : 2026-11-07 · **Statut** : accepté
- **Au propre** (Antsa, « une belle police comme une reMarkable ») : une ligne comprise s'affiche écrite au propre par le compositeur manuscrit des résultats, à la place de l'encre, dans sa couleur, au même début et jamais plus large. L'encre reste gardée (rature, correction, réglage « Mettre au propre » pour revenir à l'encre). Ce que la main ne sait pas écrire (flèche de vecteur…) garde l'encre.
- **Main levée dans la Figure** : au stylet, en mode Déplacer, sur le vide : un trait devient un segment, un rond un cercle, un tracé fermé un triangle ou un quadrilatère. Reconnaissance géométrique existante (`formes.dart`). Un sommet proche d'un point existant le réutilise ; sinon le point est créé et nommé automatiquement. Un gribouillis ne construit rien et le dit. Le doigt continue de déplacer la vue.
- **Courbes nommées** : `C : x^2+y^3=0` est l'objet C de la Figure. Les noms des courbes et des objets ne se recouvrent jamais : un nom pris devient `C_1`, `C_2` (affiché C₁).
- **Vérifié** : tests (`courbes_nommees_test`, `atelier_test`, `ecriture_resultat_test`) ; sur le Pad 7 au stylet simulé. **Reste** : un vrai stylet ; d'autres formes (rectangle libre, droite infinie).
