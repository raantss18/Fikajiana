# ADR 0034 — Idées reprises de Mikajy : police Caveat, `≈`, lecture plus vive

- **Date** : 2026-11-07 · **Statut** : accepté
- **Contexte** : Antsa juge Mikajy (https://github.com/ARHeritiana/Mikajy, GPL-3.0) « plus beau à voir et plus rapide ». On reprend des idées, aucun code ni dessin (règle 7).
- **Police** : les lettres et chiffres des résultats et du « au propre » viennent des contours de Caveat (SIL OFL 1.1, sans nom réservé, https://github.com/google/fonts/tree/main/ofl/caveat), graisse 400, aplatis par `tool/police/glyphes_caveat.py` dans `glyphes_caveat.dart`. Pas de fichier .ttf ajouté, environ 120 Ko de code. π, √, ∞, ∈, ∅, ⇔ et ℝ/ℤ gardent les tracés maison. La licence OFL est enregistrée dans la page des licences de l'app, avec celle de Nunito.
- **`≈`** : une valeur approchée s'écrit `≈ 1,609…` au lieu de `= 1,609…` ; une décimale exacte (`1/4 = 0,25`) garde `=`.
- **Vitesse** : pause avant lecture 900 → 700 ms ; quand les deux derniers traits forment un `=` au bout de leur ligne, lecture après 250 ms.
- **Pas repris pour l'instant** (TODO) : toucher un symbole pour choisir une autre lecture, apprendre des corrections, gribouiller pour effacer (déjà : rature).
- **Vérifié** : 520 tests de l'app et 483 du moteur ; sur le Pad 7, `ln(5) ≈ 1,6094379`, `det(A) = −2`, `AX=B ⇔ X=(−4 ; 9/2)` en Caveat. **Reste** : un vrai stylet pour juger de la vitesse ressentie.
