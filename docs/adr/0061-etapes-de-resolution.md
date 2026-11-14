# ADR 0061 — Étapes de résolution

- **Date** : 2026-11-14 · **Statut** : accepté (Antsa : « je veux que tu innoves » ; piste choisie : étapes de résolution)
- **Décision** : sur une équation à une inconnue, la liste de la ligne propose « étapes ». Un panneau écrit la résolution ligne par ligne, à la main
  (`EcritureAnimee`), chaque ligne numérotée avec sa raison : degré 1 (tout à gauche, isoler, diviser), degré 2 par le discriminant (a, b, c ; Δ ; une, deux ou
  aucune solution réelle), méthode du programme de première (https://eduscol.education.gouv.fr/document/24553/download).
- **Rien à la main** : chaque calcul (degré, coefficients, Δ, racines) est fait par Giac (`etapes.dart`) ; pas d'étapes plutôt que des étapes fausses
  (degré 3 et plus, coefficients littéraux, équation non polynomiale : le panneau le dit).
- **Vérifié** : Giac compilé pour Linux au commit de l'app, 13 équations (`tool/enregistrer_giac.dart`) ; ses réponses enregistrées servent de moteur aux tests
  (`etapes_test`, valeurs résolues à la main) ; `panneau_etapes_test` (numéro, raison fr/en, cas sans étapes).
- **Reste à tester** : à l'écran sur le Pad 7 et l'émulateur léger ; dérivées, systèmes et inéquations pas à pas (vagues suivantes).
