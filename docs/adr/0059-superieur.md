# ADR 0059 — Supérieur : DL, Laplace, algèbre linéaire

- **Date** : 2026-11-14 · **Statut** : accepté (vague 7 de `docs/recherche/couverture-calcul.md`, demande d'Antsa)
- **Décision** : `DL(f;a;n)` / `taylor` (Giac `taylor`, reste `x^{n+1}·order_size` écrit `o(xⁿ)`) ; `laplace(f)` en s, `invlaplace(F)` en t ;
  `rang`, `tr`, `noyau` (base en colonnes, ou {0}), `valeurspropres` (ensemble sans répétition), `vecteurspropres`, `polycar` = det(xI − A),
  `diagonaliser` (Giac `jordan` : P et D, ou P et J « non diagonalisable »). Noms anglais aussi (`rank`, `ker`, `eigenvals`…). Sur une matrice
  écrite, ou déclarée (`A=[2,1;1,2]`), avec ou sans parenthèses comme `\det`.
- **`tr` et pas `trace`** : `trace` veut déjà dire « tracer » en anglais sur la feuille (`motsTracer`).
- **Vérifié** : Giac compilé pour Linux au commit de l'app (19a710ae) : aucun plantage sur ces commandes ; réponses relues et égales à SymPy
  (banc « supérieur », `references_feuille.py`). Doc Giac : https://www-fourier.univ-grenoble-alpes.fr/~parisse/giac/doc/fr/cascmd_fr/cascmd_fr471.html
  (`taylor`), cascmd_fr703.html (`laplace`), cascmd_fr617.html (`rank`), cascmd_fr623.html (`ker`), cascmd_fr642.html (`eigenvals`), cascmd_fr646.html (`jordan`).
- **Reste à tester** : banc sur le Pad 7 ; écriture à la main (lus par le modèle, pas ajoutés aux silhouettes de mots) ; matrice tapée en ligne
  (`rang([1,2;3,4])` refusé au clavier, comme `det`) ; Laplace d'une fonction définie plus haut.
