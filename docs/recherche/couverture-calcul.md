# Couverture du calcul : NumWorks, Giac, grands logiciels et Fikajiana

> Étude du 2026-11-09 (demande d'Antsa du 2026-11-08) : tout ce que fait une calculatrice de lycée comme la NumWorks, et
> les grandes familles de Maxima, Maple, Mathematica et SageMath, en restant léger. Pour chaque fonction : ce que Giac sait
> déjà faire, ce que Fikajiana expose, ce qui manque, et la vague qui le fera.
>
> Liens Giac abrégés : `FR/` = <https://www-fourier.univ-grenoble-alpes.fr/~parisse/giac/doc/fr/cascmd_fr/>,
> `EN/` = <https://www-fourier.univ-grenoble-alpes.fr/~parisse/giac/doc/en/cascmd_en/>. « Source ✓ » : le nom est
> enregistré dans le Giac que nous compilons (geogebra/giac, commit `19a710a`, fixé par `native/giac/construire.sh`).
> NumWorks : manuel officiel, logiciel version 20, <https://www.numworks.com/fr/graphique/manuel/> ; son code est
> « All rights reserved » (<https://github.com/numworks/epsilon>) : on n'en reprend rien (règle 7).

## 1. Ce que fait la NumWorks

Quatorze applications (<https://www.numworks.com/fr/graphique/manuel/>) : Calculs, Grapheur, Python, Statistiques,
Probabilités, Équations, Suites, Régressions, Éléments, Inférence, Finance, Variables, Boîte à outils, Paramètres. Il n'y
a pas d'application Inéquations : elles se tracent dans le Grapheur
(<https://www.numworks.com/fr/graphique/manuel/grapheur/>).

| Application | Fonctions | Source |
|---|---|---|
| Calculs | exact et approché ; entier en facteurs premiers, division euclidienne ; complexe (module, argument, Re, Im) ; matrice (det, inverse, trace, formes échelonnées) ; unités SI et conversions | <https://www.numworks.com/fr/graphique/manuel/calculs/> |
| Grapheur | cartésiennes, polaires, paramétriques, inéquations, coniques ; zéros, extremums, intersection, tangente, intégrale, nombre dérivé ; **tableau de valeurs** | <https://www.numworks.com/fr/graphique/manuel/grapheur/> |
| Équations | systèmes linéaires (6 au plus), degrés 2 et 3 exacts avec discriminant, résolution numérique sur un intervalle | <https://www.numworks.com/fr/graphique/manuel/equations/> |
| Statistiques | 16 indicateurs (moyenne, écart type, variance, quartiles, médiane, mode…) ; histogramme, boîte | <https://www.numworks.com/fr/graphique/manuel/statistiques/> |
| Probabilités | uniforme, exponentielle, normale, χ², Student, Fisher ; binomiale, géométrique, Poisson, hypergéométrique ; P(X≤a), P(a≤X), P(a≤X≤b), P(X=a), calcul inverse | <https://www.numworks.com/fr/graphique/manuel/probabilites/> |
| Régressions | linéaire, proportionnelle, quadratique, cubique, quartique, logarithmique, exponentielle, puissance, trigonométrique, logistique, médiane-médiane ; r, r², R², covariance | <https://www.numworks.com/fr/graphique/manuel/regressions/> |
| Suites | explicites, récurrence d'ordre 1 ou 2 ; tableau, somme, escalier | <https://www.numworks.com/fr/graphique/manuel/suites/> |
| Inférence | tests et intervalles de confiance (proportions, moyennes, χ², pente) | <https://www.numworks.com/fr/graphique/manuel/inference/> |
| Finance | intérêts simples et composés | <https://www.numworks.com/fr/graphique/manuel/finance/> |
| Python | MicroPython 1.17 | <https://www.numworks.com/fr/graphique/manuel/python/> |
| Boîte à outils | dénombrement, lois, aléatoire, matrices (transpose, rref, dot, cross, norm), arithmétique (gcd, lcm, factor, rem, quo), arrondis, logique | <https://www.numworks.com/fr/graphique/manuel/outils/> |

## 2. Par famille : Giac, Fikajiana, manques

Colonne Fikajiana : ce que la Feuille comprend aujourd'hui (écrit à la main et au clavier), d'après
`packages/fikajiana_math/lib/src/lecteur_latex.dart`, `analyse.dart`, `saisie.dart`, `app/lib/comprendre/mots.dart` et le
Guide (`app/lib/guide/catalogue.dart`). ✅ exposé · 🟡 en partie · ❌ absent.

### 2.1 Lycée

| Fonction | Giac (doc, source ✓) | Fikajiana | Manque | Vague |
|---|---|---|---|---|
| Calcul exact et approché, fractions, puissances, racines | noyau | ✅ (Guide `operations`, `fractions`, `approche`) | — | — |
| Développer, factoriser, simplifier | `expand`, `factor`, `simplify` | ✅ (`developper`, `factoriser`, `simplifier`) | — | — |
| Équations, systèmes, discriminant | `solve` FR/cascmd_fr690.html | ✅ (`equation`, `systeme`, `discriminant`) | — | — |
| **Inéquations** | `solve` sur inégalités : non documenté ; forum : liste de conditions, incohérences signalées (<https://xcas.univ-grenoble-alpes.fr/forum/viewtopic.php?p=8004>) | 🟡 lues à la main (`\le`, `<`) ; refusées au clavier (`<`) | saisie clavier ; vérifier `solve` sur l'appareil, sinon tableau de signes | 5 |
| Fonctions, dérivée, tangente, limite, intégrale, somme | `diff`, `limit`, `integrate`, `sum` | ✅ (`derivee`, `tangente`, `limite`, `integrale`, `somme`) | dérivée en un point au clavier : à vérifier | — |
| Suites explicites et récurrentes | `seq`, récurrence calculée | ✅ (`suite`) | ordre 2 | plus tard |
| **Tableau de valeurs** | `tablefunc` FR/cascmd_fr301.html (remplit le tableur Xcas : retour hors tableur à tester) | ❌ | une commande `tableau(f;a;b;pas)` écrite comme un tableau | 4 |
| Statistiques à une variable | `mean`, `median`, `variance`, `stddev`, `quartiles` FR/cascmd_fr725.html, `quantile` | 🟡 moyenne, médiane, variance, écart type | quartiles, effectifs (valeurs pondérées) | 3 |
| **Statistiques à deux variables, régressions** | `linear_regression` FR/cascmd_fr746.html, `exponential_regression`, `logarithmic_regression`, `power_regression`, `polynomial_regression`, `logistic_regression`, `covariance`, `correlation` ; trigonométrique : `sin_regression` (non documenté) ; médiane-médiane : aucune | ❌ | listes x et y ; équation de la droite, r, r², tracé du nuage et de la courbe | 3 |
| **Lois de probabilité** | `binomial(n,k,p)` FR/cascmd_fr766.html, `binomial_cdf`, `binomial_icdf` ; `poisson*` ; `normald*` FR/cascmd_fr776.html ; `geometric*` ; `exponentiald*` ; `uniformd*` ; `student*`, `chisquare*`, `fisher*` ; hypergéométrique : **absente** (à écrire avec `comb`) | ❌ (`\binom` seulement) | `X \sim B(n;p)`, `P(X=k)`, `P(X\le k)`, `P(a\le X\le b)`, `E(X)`, `V(X)`, `σ(X)`, seuil `P(X\le k)\ge α` | **1** |
| Dénombrement | `comb`, `perm`, `factorial` FR/cascmd_fr193.html | ✅ `\binom`, `!` | arrangements `A_n^k` | 2 |
| **Arithmétique** | `iquo`, `irem` FR/cascmd_fr171.html, `iquorem`, `gcd`, `lcm`, `ifactor`, `isprime`, `nextprime`, `powmod` FR/cascmd_fr453.html, `ichinrem`, `euler` | 🟡 pgcd, ppcm, décomposer, premier, `mod` | division euclidienne écrite `a = bq + r`, congruences `a \equiv b [n]`, inverse modulaire, nombre premier suivant | 2 |
| **Nombres complexes** | `re`, `im`, `abs`, `arg` FR/cascmd_fr251.html, `conj`, `evalc` ; forme exponentielle : pas de commande, composer `abs(z)*exp(i*arg(z))` | 🟡 `i`, `\overline`, `|z|`, `\arg`, `Re`, `Im` | forme exponentielle et trigonométrique, racines n-ièmes, équations dans ℂ (`csolve`) | 6 |
| Matrices (lycée spécialité) | `det`, `inv`, `tran`, `trace` | ✅ (`matrice`, `inverse`, `axb`) | transposée, trace | 7 |
| Géométrie plane | — (Figure de Fikajiana) | ✅ (constructions, mesures) | — | — |

### 2.2 Supérieur (Maxima, Maple, Mathematica, Sage)

Une URL officielle par famille : voir § 3. Giac couvre ces familles avec les commandes ci-dessous.

| Famille | Giac (doc, source ✓) | Fikajiana | Manque | Vague |
|---|---|---|---|---|
| Développements limités, séries de Taylor | `taylor` FR/cascmd_fr471.html, `series` | ❌ | `DL_n(f;a)` ou `taylor(f;x;a;n)` | 7 |
| Équations différentielles | `desolve` FR/cascmd_fr702.html | ✅ ordre 1 ; ordre 2 à coefficients constants écrit sans `desolve` (Giac tombe, voir `docs/TODO.md` § 0) | — | — |
| Transformée de Laplace | `laplace`, `invlaplace` FR/cascmd_fr703.html | ❌ | `\mathcal{L}(f)`, inverse | 7 |
| Transformée en z | `ztrans`, `invztrans` FR/cascmd_fr704.html | ❌ | à la demande | plus tard |
| Transformée de Fourier | `fourier` documenté (EN/cascmd_en715.html) mais **absent du Giac compilé** ; coefficients `fourier_an`, `fourier_bn`, `fourier_cn` présents | ❌ | coefficients de Fourier seulement (sans nouvelle dépendance) | plus tard |
| Algèbre linéaire avancée | `rank` FR/cascmd_fr617.html, `ker` FR/cascmd_fr623.html, `image`, `rref`, `eigenvals` FR/cascmd_fr642.html, `eigenvects`, `jordan` FR/cascmd_fr646.html (pas de `diagonalize`), `charpoly` | ❌ (det, inverse seulement) | rang, noyau, valeurs et vecteurs propres, diagonalisation, polynôme caractéristique | 7 |
| Logique | `and`, `or`, `xor`, `not` FR/cascmd_fr138.html ; pas de `truth_table` | ❌ | table de vérité écrite à la main (calculée côté Dart) | plus tard |
| Ensembles | `union`, `intersect`, `minus` FR/cascmd_fr501.html | ❌ | à la demande | plus tard |
| Unités | `_m`, `convert` FR/cascmd_fr128.html, `usimplify` | ❌ | conversions (`30cm+1m`) | plus tard |
| Inférence (tests, intervalles) | `normalt`, `studentt`, `chisquaret` (non vérifié) | ❌ | intervalle de fluctuation et de confiance du lycée | après 1 |

## 3. Les grandes familles des logiciels de calcul formel

| Famille | Maxima | Mathematica | SageMath |
|---|---|---|---|
| Simplification | <https://maxima.sourceforge.io/docs/manual/Simplification.html> | <https://reference.wolfram.com/language/guide/AlgebraicTransformations.html> | <https://doc.sagemath.org/html/en/reference/calculus/sage/symbolic/expression.html> |
| Polynômes | <https://maxima.sourceforge.io/docs/manual/Polynomials.html> | <https://reference.wolfram.com/language/guide/PolynomialAlgebra.html> | <https://doc.sagemath.org/html/en/reference/polynomial_rings/index.html> |
| Arithmétique | <https://maxima.sourceforge.io/docs/manual/Number-Theory.html> | <https://reference.wolfram.com/language/guide/NumberTheory.html> | <https://doc.sagemath.org/html/en/reference/rings_standard/index.html> |
| Complexes | <https://maxima.sourceforge.io/docs/manual/Elementary-Functions.html> | <https://reference.wolfram.com/language/guide/ComplexNumbers.html> | <https://doc.sagemath.org/html/en/reference/rings_numerical/index.html> |
| Analyse | <https://maxima.sourceforge.io/docs/manual/Integration.html> | <https://reference.wolfram.com/language/guide/Calculus.html> | <https://doc.sagemath.org/html/en/reference/calculus/index.html> |
| Séries | <https://maxima.sourceforge.io/docs/manual/Sums-Products-and-Series.html> | <https://reference.wolfram.com/language/guide/SeriesExpansions.html> | <https://doc.sagemath.org/html/en/reference/power_series/index.html> |
| Équations différentielles | <https://maxima.sourceforge.io/docs/manual/Differential-Equations.html> | <https://reference.wolfram.com/language/guide/DifferentialEquations.html> | <https://doc.sagemath.org/html/en/reference/calculus/sage/calculus/desolvers.html> |
| Algèbre linéaire | <https://maxima.sourceforge.io/docs/manual/Matrices-and-Linear-Algebra.html> | <https://reference.wolfram.com/language/guide/MatrixOperations.html> | <https://doc.sagemath.org/html/en/reference/matrices/index.html> |
| Probabilités et statistiques | <https://maxima.sourceforge.io/docs/manual/Package-distrib.html> | <https://reference.wolfram.com/language/guide/ProbabilityAndStatistics.html> | <https://doc.sagemath.org/html/en/reference/probability/index.html> |
| Transformées | <https://maxima.sourceforge.io/docs/manual/Integration.html> (`laplace`) | <https://reference.wolfram.com/language/guide/IntegralTransforms.html> | <https://doc.sagemath.org/html/en/reference/calculus/sage/calculus/calculus.html> |
| Géométrie | non vérifié | <https://reference.wolfram.com/language/guide/GeometricComputation.html> | <https://doc.sagemath.org/html/en/reference/discrete_geometry/index.html> |
| Logique | non vérifié | <https://reference.wolfram.com/language/guide/BooleanComputation.html> | <https://doc.sagemath.org/html/en/reference/logic/index.html> |
| Ensembles | <https://maxima.sourceforge.io/docs/manual/Sets.html> | <https://reference.wolfram.com/language/guide/OperationsOnSets.html> | <https://doc.sagemath.org/html/en/reference/sets/index.html> |
| Unités | <https://maxima.sourceforge.io/docs/manual/Package-unit.html> | <https://reference.wolfram.com/language/guide/Units.html> | <https://doc.sagemath.org/html/en/reference/calculus/sage/symbolic/units.html> |

Maple : le site d'aide bloque les robots ; pages repérées par moteur de recherche, non ouvertes :
<https://www.maplesoft.com/support/help/Maple/view.aspx?path=NumberTheory>,
<https://www.maplesoft.com/support/help/maple/view.aspx?path=LinearAlgebra>,
<https://www.maplesoft.com/support/help/Maple/view.aspx?path=Statistics>,
<https://www.maplesoft.com/support/help/Maple/view.aspx?path=inttrans%2Finvlaplace>,
<https://www.maplesoft.com/support/help/Maple/view.aspx?path=Logic>,
<https://www.maplesoft.com/support/help/Maple/view.aspx?path=Units>.

## 4. Python : écarté

Antsa, 2026-11-09 : « on ne va pas faire du python ». Pour mémoire, les poids relevés : MicroPython « 256k of code space
and 16k of RAM » (<https://micropython.org/>) ; CPython officiel pour Android arm64, archive de 21 432 357 octets
(<https://www.python.org/ftp/python/3.14.4/>). Tout le calcul passe par Giac, déjà embarqué : **aucune nouvelle
dépendance** pour les vagues ci-dessous.

## 5. Vagues (une PR chacune, lycée d'abord)

1. Lois de probabilité. 2. Arithmétique et dénombrement. 3. Statistiques à deux variables et régressions (plus quartiles).
4. Tableau de valeurs. 5. Inéquations (clavier, vérification de `solve`). 6. Nombres complexes. 7. Supérieur : Taylor,
Laplace, algèbre linéaire (rang, noyau, valeurs propres, `jordan`), transposée, trace.

Chaque fonction : écrite à la main et au clavier, résultat vérifié contre SymPy au banc (`tool/banc/`), entrée au Guide,
CHANGELOG, poids de l'APK mesuré (73 789 783 octets avant la vague 1).

## Vérifié / Supposé / Reste à tester

- **Vérifié** : la liste NumWorks et le contenu de ses pages ; les noms et pages de la doc Giac ; leur présence dans le
  source compilé (lecture du source) ; ce que Fikajiana lit aujourd'hui (code et Guide cités).
- **Supposé** : que chaque nom présent dans le source est appelable dans `libfikajiana_giac.so` (fichiers inclus dans
  `native/giac/CMakeLists.txt`, aucun appel encore fait) ; le sens de `sin_regression`, lu dans le code.
- **Reste à tester sur le Pad 7** : `solve` sur des inégalités, `tablefunc` hors tableur, `binomial_icdf` et
  `normald_icdf`, `sin_regression`, l'absence de `fourier`.
