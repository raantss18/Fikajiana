# ADR 0055 — Statistiques à deux variables et quartiles du lycée

- **Date** : 2026-11-09 · **Statut** : accepté (vague 3 de `docs/recherche/couverture-calcul.md`)
- **Décision** : `ajustement([x];[y])` rend a, b et r de la droite des moindres carrés ; modèles `exp` (y = a·e^{bx}), `ln` (y = a·ln x + b), `puissance` (y = a·x^b), linéarisés comme sur les calculatrices, et `2` (y = ax² + bx + c, équations normales) ; `correlation`, `covariance` (divisée par n) ; `quartiles(…)` selon le lycée français : Q1 de rang ⌈n/4⌉, Q3 de rang ⌈3n/4⌉ (pas les quartiles interpolés de Giac).
- **Calcul** : les sommes Σx, Σxy… s'écrivent terme à terme et Giac ne fait que l'arithmétique ; on ne dépend pas des conventions de `linear_regression` et des autres (doc Giac cascmd_fr746 et suivantes), ni d'une nouvelle dépendance.
- **Saisie** : au clavier ; listes en `[…]`, valeurs séparées par `;` (la virgule reste décimale). À la main, les mots `ajustement`, `quartiles`, `correlation`, `covariance` ne s'ajoutent pas à la reconnaissance par silhouette : essayés, ils coupaient de nouveau `g(x) = x − 1/x` d'une feuille d'Antsa (`feuille_pad7_relue_test`).
- **Vérifié** : voir `docs/TODO.md`.
