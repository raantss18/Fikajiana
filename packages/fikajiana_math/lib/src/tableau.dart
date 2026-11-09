/// Le tableau de valeurs (vague 4 de `docs/recherche/couverture-calcul.md`) :
/// `tableau(f;0;5;1)` pour une fonction définie plus haut, ou
/// `tableau(x^2-1;-2;2;0{,}5)` pour une expression en x. Le résultat est une
/// matrice de deux lignes : x, puis f(x), valeurs exactes.
///
/// Les valeurs de x se calculent ici (nombres écrits) ; Giac calcule f(x)
/// à chacune, comme `f(2)=` sur la Feuille.
library;

import 'package:fikajiana_math/src/analyse.dart';
import 'package:fikajiana_math/src/redressement.dart' show sansLeftRight;

/// Au plus tant de colonnes : au-delà, le tableau ne tient pas sur la page.
const colonnesMax = 21;

String _nu(String latex) => sansLeftRight(latex)
    .replaceAllMapped(
      RegExp(
        r'\\(?:mathrm|operatorname|text|textrm|textit)\s*\{\s*([^{}]*?)\s*\}',
      ),
      (m) => m[1]!,
    )
    .replaceAll(RegExp(r'\\[,;:!]|\\quad'), '')
    .replaceAll(RegExp(r'\s+'), '')
    .trim();

List<String> _couper(String texte) {
  final morceaux = <String>[];
  var profondeur = 0;
  var debut = 0;
  for (var i = 0; i < texte.length; i++) {
    final c = texte[i];
    if ('([{'.contains(c)) profondeur++;
    if (')]}'.contains(c)) profondeur--;
    if (c == ';' && profondeur == 0) {
      morceaux.add(texte.substring(debut, i));
      debut = i + 1;
    }
  }
  morceaux.add(texte.substring(debut));
  return morceaux;
}

/// Un nombre écrit : `3`, `-2`, `0{,}5`, `2.5`, `\frac{1}{2}`.
double? _nombre(String texte) {
  final t = texte.replaceAll('{,}', '.').replaceAll(',', '.');
  final simple = double.tryParse(t);
  if (simple != null) return simple;
  final f = RegExp(r'^(-?)\\frac\{(-?\d+)\}\{(\d+)\}$').firstMatch(t);
  if (f == null) return null;
  final v = int.parse(f[2]!) / int.parse(f[3]!);
  return f[1] == '-' ? -v : v;
}

/// x en Giac, exact quand c'est possible : `1/2` plutôt que `0.5`.
String _valeur(double v) {
  if (v == v.roundToDouble()) return '${v.round()}';
  for (final d in [2, 4, 5, 10, 20, 100]) {
    final n = v * d;
    if ((n - n.roundToDouble()).abs() < 1e-9) return '(${n.round()}/$d)';
  }
  return '$v';
}

/// `tableau(f;a;b;pas)` : une ligne de tableau de valeurs, ou `null`.
Analyse? analyserTableau(
  String latex, {
  Map<String, DefinitionFonction> definitions = const {},
  Map<String, String> valeurs = const {},
}) {
  final ligne = _nu(latex);
  final appel = RegExp(r'^(?:tableau|table|tableaudevaleurs)\((.*)\)=?$')
      .firstMatch(ligne);
  if (appel == null) return null;
  final morceaux = _couper(appel[1]!);
  if (morceaux.length < 3 || morceaux.length > 4) {
    throw const ErreurLatex('tableau(f;début;fin;pas) attendu');
  }
  final debut = _nombre(morceaux[1]);
  final fin = _nombre(morceaux[2]);
  final pas = morceaux.length == 4 ? _nombre(morceaux[3]) : 1.0;
  if (debut == null || fin == null || pas == null || pas <= 0) {
    throw const ErreurLatex('tableau : début, fin et pas en nombres');
  }
  final xs = <double>[];
  for (var k = 0; debut + k * pas <= fin + 1e-9; k++) {
    xs.add(debut + k * pas);
    if (xs.length > colonnesMax) {
      throw const ErreurLatex('tableau : plus de 21 valeurs');
    }
  }
  if (xs.isEmpty) throw const ErreurLatex('tableau : fin avant le début');

  // `f` définie plus haut, ou une expression en x.
  final nom = morceaux.first;
  final definition = definitions[nom];
  String image(String x) {
    if (definition != null) return definition.appel(x);
    final corps = analyserLatex(
      nom,
      definitions: definitions,
      valeurs: valeurs,
    );
    return 'subst(${corps.giac},x=$x)';
  }

  final colonnes = [for (final x in xs) _valeur(x)];
  return Analyse(
    TypeExpression.calcul,
    '[[${colonnes.join(',')}],[${colonnes.map(image).join(',')}]]',
    demandeResultat: true,
  );
}
