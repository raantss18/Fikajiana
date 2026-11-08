# ADR 0052 — Lois de probabilité écrites comme au tableau

- **Date** : 2026-11-09 · **Statut** : accepté (vague 1 de `docs/recherche/couverture-calcul.md`)
- **Décision** : une loi se déclare sur sa ligne, `X \sim B(n;p)` (aussi `N`, `P`, `G`, `E`, `U`, polices `\mathcal` acceptées), et vaut pour les lignes dessous comme `a=2` (valeur de feuille `§loi§…`, qui fait échouer tout autre usage de X au lieu de calculer faux). Puis `P(X=3)=`, `P(X\le3)=`, `P(2\le X<5)=`, `E(X)=`, `V(X)=`, `\sigma(X)=`, et le seuil `P(X\le k)\ge α` (discret) ou `P(X\le t)=α` (continu).
- **Notation** : `N(μ;σ²)`, le second paramètre est la variance (programme du lycée) ; géométrique sur 1, 2, 3… (rang du premier succès).
- **Calcul** : loi discrète, une somme de termes (`comb`, `exp`, `factorial`), bornes ramenées à des entiers côté Dart, sans dépendre des `*_cdf` de Giac ; loi continue, sa fonction de répartition (`erf`, `exp`, linéaire) ; quantiles par `binomial_icdf`, `poisson_icdf`, `geometric_icdf`, `normald_icdf` (doc Giac, cascmd_fr768 et suivantes) ou leur formule. Aucune nouvelle dépendance.
- **Écarté** : les noms de la NumWorks (`binomcdf`, `invnorm`) : on écrit comme au tableau ; l'hypergéométrique (absente de Giac) : plus tard, avec `comb`.
- **Vérifié** : voir `docs/TODO.md` (banc contre `sympy.stats`, `tool/banc/comparer_feuille.py`).
