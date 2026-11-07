# ADR 0024 — Une saisie, une feuille, un verbe

- **Date** : 2026-11-07 · **Statut** : accepté (choix d'Antsa), livré par étapes
- **Pourquoi** : le clavier n'acceptait bien que le LaTeX, et le reste était faux sans le dire. Calcul et graphique vivent dans deux listes.
- **Pivot** : le LaTeX reste ce qu'on garde. `lireSaisie` traduit le texte tapé vers le LaTeX, la correction fait le chemin inverse.
- **Lecture** : `sin 2x` = `sin(2x)` ; `1/2x` = `(1/2)x`, l'autre sens à un toucher ; virgule décimale entre chiffres collés ; `2 3` et les mots inconnus sont refusés et nommés ; parenthèse ouverte fermée toute seule.
- **Verbe** : pas de mode. Le bouton dit Calculer, Résoudre en x ou Tracer, d'après ce qui est compris.
- **Barre** : « Taper un calcul » en bas, panneau au-dessus du clavier.
- **À venir (choix d'Antsa)** : le graphique devient une vue des mêmes lignes, à côté sur tablette ; `a=2` définit `a` (x, y, t, r, θ restent des équations).
- **Écarté** : éditeur structuré (`math_keyboard`) : perd `racine de 2` et le collage. Idées d'usage seulement : GeoGebra, Desmos, Qalculate ; aucun code repris.
- **Sources** : https://geogebra.github.io/docs/manual/en/Input_Bar/ · https://qalculate.github.io/manual/qalculate-expressions.html · https://docs.sympy.org/latest/modules/parsing.html
