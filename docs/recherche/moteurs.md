# Calcul formel, graphique, géométrie, rendu (étude du 2026-11-05)

> Sites bloqués pendant l'étude : geogebra.org, xcas.univ-grenoble-alpes.fr, gnu.org, f-droid.org, docs.flutter.dev.
> « Vérifié (extrait) » = lu dans un extrait de recherche, page non ouverte.

## Moteurs de calcul formel

| Moteur | Licence | Couverture | Android | Statut |
|---|---|---|---|---|
| **Giac/Xcas** | GPL-3 | CAS complet ; moteur de GeoGebra et de la HP Prime | miroir `geogebra/giac` : wrappers Android, 4 ABI, GMP/MPFR | licence (extrait) [1][2] ; build vérifié [3][4] |
| SymEngine | MIT | `series` ; pas d'intégration générale ni de solveur trouvés | rien | [5][6][7] |
| Maxima (ECL) | GPL-2+ | complet | app figée depuis 2023-09 | extrait [8][9] |
| PARI/GP | GPL-2+ | théorie des nombres | PariDroid (F-Droid) | extrait [10] |
| SymPy + Chaquopy | BSD / MIT | complet | embarque Python (lourd) | [12] |
| Symja | GPL-3 | dérivées, intégrales (Rubi), solve, algèbre linéaire | Java | [13] |

## Graphique, géométrie, rendu

- `fl_chart` (MIT) et `graphic` (MIT) : graphiques de données, pas de tracé de fonctions [15][16] → **CustomPainter maison**
  (échantillonnage adaptatif, marching squares pour l'implicite). 3D : `flutter_scene` exige le canal master [17] → différé.
- Géométrie : GeoGebra code GPL-3+, installateurs/contenus non commerciaux, nom réservé [18][19] ; JSXGraph LGPL-3+/MIT [20] ;
  Kig, Dr. Geo, CaRMetal GPL [21] → **noyau Dart maison** (graphe de dépendances), architecture inspirée de JSXGraph.
- Rendu : `flutter_math_fork` 0.7.4 (Apache-2.0, KaTeX en Dart pur, peu maintenu) [22] ; `flutter_tex` 5.3.0 (BSD-3, MathJax
  hors ligne) [23] ; `math_keyboard` 0.4.0 (BSD-3) [25].
- Licences : Apache/MIT/BSD/LGPL-3 compatibles avec une distribution GPL-3 [26] ; F-Droid exige la compilation depuis les
  sources (Giac, GMP, MPFR à compiler dans la recette) [27].
- Outils : Penpot (MPL-2.0) [28] ; Material 3 Expressive non officiel dans Flutter [29][30] ; Widget Previewer expérimental [31] ;
  AVD « Resizable » (téléphone / pliable / tablette) [32][33].

## Risques

1. Chaîne Android de Giac basée sur Crystax NDK 10.2.1, obsolète [3] → portage NDK actuel à faire (tranche T2).
2. Taille APK et démarrage non mesurés. 3. `flutter_math_fork` peu maintenu. 4. 3D dépendante du canal master.

## Sources

[1] https://xcas.univ-grenoble-alpes.fr/en.html [2] https://en.wikipedia.org/wiki/Xcas
[3] https://github.com/geogebra/giac/blob/master/ANDROID_README.md [4] https://github.com/geogebra/giac
[5] https://github.com/symengine/symengine [6] https://github.com/symengine/symengine/issues/1597
[7] https://github.com/symengine/symengine/wiki/expression-series-expansion [8] https://github.com/YasuakiHonda/Maxima-on-Android-AS
[9] https://sourceforge.net/projects/maxima-on-android/ [10] https://pari.math.u-bordeaux.fr/paridroid/
[12] https://github.com/chaquo/chaquopy [13] https://github.com/axkr/symja_android_library
[15] https://pub.dev/packages/fl_chart [16] https://pub.dev/packages/graphic [17] https://pub.dev/packages/flutter_scene
[18] https://www.geogebra.org/license [19] https://github.com/geogebra/geogebra [20] https://github.com/jsxgraph/jsxgraph
[21] https://en.wikipedia.org/wiki/Kig_(software) [22] https://pub.dev/packages/flutter_math_fork
[23] https://pub.dev/packages/flutter_tex [25] https://pub.dev/packages/math_keyboard
[26] https://www.gnu.org/licenses/license-list.html [27] https://f-droid.org/docs/Inclusion_Policy
[28] https://github.com/penpot/penpot [29] https://github.com/flutter/flutter/issues/168813 [30] https://pub.dev/packages/m3_expressive
[31] https://docs.flutter.dev/tools/widget-previewer [32] https://developer.android.com/studio/run/resizable-emulator
