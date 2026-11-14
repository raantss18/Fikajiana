# ADR 0058 — Nombres complexes

- **Date** : 2026-11-14 · **Statut** : accepté (vague 6 de `docs/recherche/couverture-calcul.md`, « prochaine tâche faisable sans tablette », Antsa)
- **Décision** : `formeexp(z)` → r e^{iθ}, `formetrigo(z)` → r(cos θ + i sin θ), `racines(n;a)` → z_k = ⁿ√|a| e^{i(θ+2kπ)/n} (2 ≤ n ≤ 12) ; Giac calcule `[simplify(abs(z)),simplify(arg(z))]`, la forme s'écrit en Dart (`complexes.dart`) : Giac remet `exp(iθ)` sous forme algébrique et `rectangular2polar` laisse `π/3−2π/2`. Une équation d'inconnue `z`, ou qui contient `i`, se résout dans ℂ par `csolve`.
- **Garde-fou** : `csolve` fait **tomber Giac** (SIGSEGV ou abort) dès le degré 3 : `z^3=-8`, `z^3-1=0`, `z^4=16`, `z^4+16=0`, et aussi `cfactor`, `cZeros`. Il n'est appelé qu'en degré 1 ou 2 (`ifte(degree(…)…,csolve(…),undef)`) ; sinon pas de résultat, l'app ne plante pas. Pour zⁿ = a : `racines(n;a)`.
- **Corrigé en route** : `z^2+1=0` donnait S = ∅ (`solve` cherche dans ℝ) ; `2*i` s'affichait avec son étoile (`latexLisible`).
- **Vérifié** : Giac compilé pour Linux au commit de l'app (19a710ae, mêmes correctifs) ; les 10 lignes du banc « complexes » y donnent les valeurs de SymPy (`references_feuille.py`). Doc Giac `abs`, `arg` : https://www-fourier.univ-grenoble-alpes.fr/~parisse/giac/doc/fr/cascmd_fr/cascmd_fr251.html
- **Reste à tester** : banc sur le Pad 7 (arm64) ; écriture à la main de `formeexp`, `racines` (lus par le modèle, pas ajoutés aux silhouettes de mots) ; degré ≥ 3 dans ℂ.
