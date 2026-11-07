# ADR 0025 — Lecture du calcul formel et banc croisé avec SymPy

- **Date** : 2026-11-07 · **Statut** : accepté, banc à refaire sur un appareil arm64 réel
- **Constat** : un inventaire de 90 écritures a trouvé des résultats faux sans avertissement. `\int_0^1 x^2 dx` rendait une primitive, `\begin{vmatrix}` la matrice, `\frac{d}{dx}` et `\operatorname{ppcm}` un produit de lettres, `u_{n+1}` la variable `u_n` plus 1.
- **Règle** : ce qui n'est pas compris est refusé, jamais deviné. Un nom inconnu n'est plus le produit de ses lettres ; une borne seule ou `\frac{dy}{dx}` sans expression sont refusées. Comme en LaTeX, une borne sans accolades ne prend qu'un signe.
- **Ajouts** : dérivées (`\frac{d}{dx}`, `f'`, `(…)'`, `\partial`), limites à droite et à gauche, `\binom`, `C_n^k`, `A_n^k`, pgcd, ppcm, modulo, partie entière, `\log_b`, déterminant, transposée, conjugué, argument, Re, Im, pourcentage, inéquations.
- **Modulo** : `a-b*floor(a/b)`, car le `irem` de Giac rendrait -1 pour -7 mod 3, là où l'usage scolaire attend 2.
- **Fonctions** : une définition n'est plus envoyée à Giac : `y=2x+1` laisse `y` libre. La feuille les remplace elle-même (ADR 0024).
- **Banc** : `tool/banc/references.py` écrit les résultats de référence en SymPy, sans passer par le lecteur de l'app ; `tool/banc/lancer.sh` les compare à Giac sur un appareil, numériquement. Il s'installe à côté de l'app (`mg.fikajiana.app.banc`), sur l'écran secondaire s'il y en a un. La CI ne peut pas le lancer : pas de Giac pour l'ordinateur.
- **Limites** : suites : voir ADR 0027. Inéquations à une inconnue seulement ; deux signes (`1<x<3`) refusés. Une transposée n'est lue que juste après une matrice écrite.
- **Sources** : SymPy 1.14 (https://www.sympy.org) ; Giac (https://www-fourier.univ-grenoble-alpes.fr/~parisse/giac/doc/en/cascmd_en/) à vérifier page par page, non relue pour cet ADR.
