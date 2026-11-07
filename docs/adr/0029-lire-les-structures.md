# ADR 0029 — Lire les structures à partir des traits

- **Date** : 2026-11-07 · **Statut** : accepté, à mesurer sur le Pad 7
- **Constat** (Pad 7) : le modèle lit mal ce qui sort d'une ligne : `c t + ( 1 - 5 - 3 \\atop 4 - 2 - 8 \\atop 3 5 - 7 )` pour un déterminant 3×3, avec des signes inventés ; `\\det ( - 1 3 )` en perdant une ligne ; `5/AB` pour un vecteur ; `( \\overrightarrow{AB} ) ( 1` pour une norme. Corriger ces lectures après coup ne se termine jamais.
- **Décision** : ces structures se voient sur les traits. On les découpe (deux grands traits et des cases ; un trait plat coiffant un nom ; deux doubles barres), et le modèle ne lit que des morceaux simples.
- **Coût** : une lecture par case et par morceau. Une matrice 3×3 prend plus que le budget d'une ligne : à mesurer.
- **Repli** : rien de reconnu, ou un morceau illisible : le modèle lit le tout, comme avant.
- **Feuille** : points, vecteurs et `a=2` rejoignent les fonctions. `\\vec{AB}`, `\\|\\vec{AB}\\|` et `AB` se calculent ; un vecteur calculé se place dans la Figure.
- **Limite** : une case mal lue reste fausse et le déterminant avec. Toucher le résultat montre ce qui a été lu.
