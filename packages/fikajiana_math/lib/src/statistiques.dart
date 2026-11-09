/// Statistiques à deux variables et quartiles, écrits comme au tableau
/// (vague 3 de `docs/recherche/couverture-calcul.md`) :
///
/// - `ajustement([1;2;3;4];[2;4;5;8])` : la droite des moindres carrés
///   y = ax + b, et le coefficient de corrélation r ;
/// - `ajustement([…];[…];exp)` : y = a·e^{bx} (droite de ln y en x) ;
///   `ln` : y = a·ln x + b ; `puissance` : y = a·x^b (droite de ln y en
///   ln x) ; `2` : y = ax² + bx + c (moindres carrés) ;
/// - `correlation([…];[…])`, `covariance([…];[…])` (population, n) ;
/// - `quartiles(…)` : Q1, médiane, Q3, définition du lycée français
///   (Q1 = valeur de rang ⌈n/4⌉, Q3 = valeur de rang ⌈3n/4⌉).
///
/// Les sommes s'écrivent ici terme à terme : Giac ne fait que de
/// l'arithmétique, sans dépendre de ses conventions de régression.
library;

import 'package:fikajiana_math/src/analyse.dart';
import 'package:fikajiana_math/src/redressement.dart' show sansLeftRight;

String _nu(String latex) => sansLeftRight(latex)
    .replaceAllMapped(
      RegExp(
        r'\\(?:mathrm|operatorname|text|textrm|textit)\s*\{\s*([^{}]*?)\s*\}',
      ),
      (m) => m[1]!,
    )
    .replaceAll(RegExp(r'\\[{}]'), '')
    .replaceAll(RegExp(r'\\[,;:!]|\\quad'), '')
    .replaceAll(RegExp(r'\s+'), '')
    .trim();

/// Coupe [texte] à chaque [signe] hors des parenthèses et crochets.
List<String> _couper(String texte, String signe) {
  final morceaux = <String>[];
  var profondeur = 0;
  var debut = 0;
  for (var i = 0; i < texte.length; i++) {
    final c = texte[i];
    if ('([{'.contains(c)) profondeur++;
    if (')]}'.contains(c)) profondeur--;
    if (c == signe && profondeur == 0) {
      morceaux.add(texte.substring(debut, i));
      debut = i + 1;
    }
  }
  morceaux.add(texte.substring(debut));
  return morceaux;
}

/// Une liste écrite `[1;2;3]`, `(1;2;3)`, `{1;2;3}` : ses valeurs en Giac.
List<String>? _liste(String texte, Map<String, String> valeurs) {
  final m = RegExp(r'^[\[\({](.*)[\]\)}]$').firstMatch(texte);
  if (m == null) return null;
  var morceaux = _couper(m[1]!, ';');
  if (morceaux.length == 1) morceaux = _couper(m[1]!, ',');
  return [
    for (final v in morceaux)
      if (v.isNotEmpty) analyserLatex(v, valeurs: valeurs).giac,
  ];
}

/// La somme Σ f(xᵢ, yᵢ), écrite terme à terme.
String _somme(
  List<String> x,
  List<String> y,
  String Function(String, String) f,
) => '(${[for (var i = 0; i < x.length; i++) f(x[i], y[i])].join('+')})';

/// La droite des moindres carrés de (x, y) : (a, b) en Giac, et r.
(String, String, String) _droite(List<String> x, List<String> y) {
  final n = x.length;
  final sx = _somme(x, y, (a, _) => '($a)');
  final sy = _somme(x, y, (_, b) => '($b)');
  final sxy = _somme(x, y, (a, b) => '($a)*($b)');
  final sxx = _somme(x, y, (a, _) => '($a)^2');
  final syy = _somme(x, y, (_, b) => '($b)^2');
  final a = '(($n*$sxy-$sx*$sy)/($n*$sxx-$sx^2))';
  final b = '(($sy-$a*$sx)/$n)';
  final r = '(($n*$sxy-$sx*$sy)/sqrt(($n*$sxx-$sx^2)*($n*$syy-$sy^2)))';
  return (a, b, r);
}

/// `ajustement(…)`, `correlation(…)`, `covariance(…)`, `quartiles(…)` :
/// une ligne de statistiques, ou `null`.
Analyse? analyserStatistiques(
  String latex, {
  Map<String, String> valeurs = const {},
}) {
  final ligne = _nu(latex);
  final appel = RegExp(
    r'^(ajustement|regression|régression|correlation|corrélation|covariance|quartiles)\((.*)\)=?$',
  ).firstMatch(ligne);
  if (appel == null) return null;
  final nom = appel[1]!
      .replaceAll('é', 'e')
      .replaceAll('regression', 'ajustement');
  final arguments = _couper(appel[2]!, ';');

  if (nom == 'quartiles') {
    // `quartiles(3;1;7;5)` ou `quartiles([3;1;7;5])`.
    final valeursListe = arguments.length == 1
        ? _liste(arguments.single, valeurs)
        : [for (final v in arguments) analyserLatex(v, valeurs: valeurs).giac];
    if (valeursListe == null || valeursListe.length < 2) {
      throw const ErreurLatex('quartiles : une liste de nombres attendue');
    }
    final n = valeursListe.length;
    final l = 'sort([${valeursListe.join(',')}])';
    // Rangs 1, 2, … : l'indice de Giac commence à 0.
    String rang(String r) => '$l[$r-1]';
    final mediane = n.isOdd
        ? rang('${(n + 1) ~/ 2}')
        : '(${rang('${n ~/ 2}')}+${rang('${n ~/ 2 + 1}')})/2';
    return Analyse(
      TypeExpression.systeme,
      '[[${rang('ceil($n/4)')},$mediane,${rang('ceil(3*$n/4)')}]]',
      inconnues: const ['Q_1', 'M_e', 'Q_3'],
    );
  }

  if (arguments.length < 2) {
    throw const ErreurLatex('deux listes attendues : ajustement([x];[y])');
  }
  final x = _liste(arguments[0], valeurs);
  final y = _liste(arguments[1], valeurs);
  if (x == null || y == null || x.length != y.length || x.length < 2) {
    throw const ErreurLatex('deux listes de même longueur attendues');
  }
  final n = x.length;

  if (nom == 'covariance') {
    final mx = '(${_somme(x, y, (a, _) => '($a)')}/$n)';
    final my = '(${_somme(x, y, (_, b) => '($b)')}/$n)';
    return Analyse(
      TypeExpression.calcul,
      '${_somme(x, y, (a, b) => '($a)*($b)')}/$n-$mx*$my',
      demandeResultat: true,
    );
  }
  if (nom == 'correlation') {
    return Analyse(
      TypeExpression.calcul,
      'evalf(${_droite(x, y).$3})',
      demandeResultat: true,
    );
  }

  final modele = arguments.length > 2 ? arguments[2].toLowerCase() : '';
  switch (modele) {
    case '' || 'lineaire' || 'linéaire' || 'affine':
      final (a, b, r) = _droite(x, y);
      return Analyse(
        TypeExpression.systeme,
        '[[evalf($a),evalf($b),evalf($r)]]',
        inconnues: const ['a', 'b', 'r'],
      );
    case 'exp' || 'exponentiel' || 'exponentielle':
      // ln y = bx + ln a.
      final (pente, origine, _) = _droite(x, [for (final v in y) 'ln($v)']);
      return Analyse(
        TypeExpression.systeme,
        '[[evalf(exp($origine)),evalf($pente)]]',
        inconnues: const ['a', 'b'],
      );
    case 'ln' || 'log' || 'logarithmique':
      // y = a ln x + b.
      final (a, b, _) = _droite([for (final v in x) 'ln($v)'], y);
      return Analyse(
        TypeExpression.systeme,
        '[[evalf($a),evalf($b)]]',
        inconnues: const ['a', 'b'],
      );
    case 'puissance' || 'power':
      // ln y = b ln x + ln a.
      final (pente, origine, _) = _droite(
        [for (final v in x) 'ln($v)'],
        [for (final v in y) 'ln($v)'],
      );
      return Analyse(
        TypeExpression.systeme,
        '[[evalf(exp($origine)),evalf($pente)]]',
        inconnues: const ['a', 'b'],
      );
    case '2' || 'quadratique' || 'degre2':
      // Équations normales : (VᵀV) (a b c)ᵀ = Vᵀ y, V = [xᵢ², xᵢ, 1].
      final v = '[${[for (final xi in x) '[($xi)^2,($xi),1]'].join(',')}]';
      final colonne = '[${[for (final yi in y) '[($yi)]'].join(',')}]';
      final coefficients = 'inv(tran($v)*$v)*tran($v)*$colonne';
      return Analyse(
        TypeExpression.systeme,
        '[evalf(tran($coefficients)[0])]',
        inconnues: const ['a', 'b', 'c'],
      );
    default:
      throw ErreurLatex('modèle inconnu : $modele');
  }
}
