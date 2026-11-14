/// Les nombres complexes du lycée (vague 6 de
/// `docs/recherche/couverture-calcul.md`, ADR 0058) :
///
/// - `formeexp(1+i)` : √2 e^{iπ/4} ;
/// - `formetrigo(1+i)` : √2 (cos π/4 + i sin π/4) ;
/// - `racines(3;8i)` : les racines n-ièmes, z_k = ⁿ√r e^{i(θ+2kπ)/n}.
///
/// Giac remet `exp(iθ)` sous forme algébrique, et son `rectangular2polar`
/// laisse parfois un angle non simplifié (`π/3 − 2π/2`) : Giac calcule donc
/// seulement le module et l'argument simplifiés, et la forme s'écrit ici.
/// Commandes Giac `abs`, `arg` :
/// <https://www-fourier.univ-grenoble-alpes.fr/~parisse/giac/doc/fr/cascmd_fr/cascmd_fr251.html>.
library;

import 'package:fikajiana_math/src/lecteur_latex.dart' show normaliserNom;

/// Ce qu'une ligne demande d'un nombre complexe.
enum FormeComplexe {
  /// r e^{iθ}.
  exponentielle,

  /// r (cos θ + i sin θ).
  trigonometrique,

  /// Les n racines n-ièmes.
  racines,
}

/// Noms (sans accent ni tiret) de chaque forme, en français et en anglais.
const Map<String, FormeComplexe> nomsDeFormesComplexes = {
  'formeexp': FormeComplexe.exponentielle,
  'formeexponentielle': FormeComplexe.exponentielle,
  'expform': FormeComplexe.exponentielle,
  'formetrigo': FormeComplexe.trigonometrique,
  'formetrigonometrique': FormeComplexe.trigonometrique,
  'trigform': FormeComplexe.trigonometrique,
  'racines': FormeComplexe.racines,
  'nthroots': FormeComplexe.racines,
};

/// La forme que demande [ligne] (LaTeX lu ou tapé), ou `null`.
FormeComplexe? formeDemandee(String ligne) {
  final nom = RegExp(
    r'^\s*\\?(?:(?:operatorname|mathrm|text|textrm)\s*\{\s*)?([A-Za-zéèêàùûôîç\s_-]+?)\s*\}?\s*(?:\\left)?\s*\(',
  ).firstMatch(ligne);
  if (nom == null) return null;
  return nomsDeFormesComplexes[normaliserNom(nom[1]!)];
}

/// Ce que Giac calcule pour [forme] : `[module, argument]`, ou pour les
/// racines `[ⁿ√r, [θ₀, …, θₙ₋₁]]`. [degres] : Giac rend alors l'argument en
/// degrés ; l'exponentielle le veut en radians.
String giacFormeComplexe(
  FormeComplexe forme,
  String z, {
  int n = 1,
  bool degres = false,
}) {
  final argument = degres ? 'arg($z)*pi/180' : 'arg($z)';
  if (forme != FormeComplexe.racines) {
    return '[simplify(abs($z)),simplify($argument)]';
  }
  final angles = [
    for (var k = 0; k < n; k++) 'simplify(($argument+2*$k*pi)/$n)',
  ];
  return '[simplify(abs($z)^(1/$n)),[${angles.join(',')}]]';
}

/// Écrit la réponse de Giac (LaTeX de `[r,θ]` ou `[r,[θ₀,…]]`) sous la
/// [forme] demandée. Ce qui n'a pas la forme attendue rend `null` : rien
/// n'est deviné.
String? ecrireFormeComplexe(FormeComplexe forme, String reponse) {
  final morceaux = _liste(reponse);
  if (morceaux == null || morceaux.length != 2) return null;
  final r = _propre(morceaux[0]);
  if (forme == FormeComplexe.racines) {
    final angles = _liste(morceaux[1]);
    if (angles == null || angles.isEmpty) return null;
    if (r == '0') return 'z_{0}=0';
    return [
      for (var k = 0; k < angles.length; k++)
        'z_{$k}=${_exponentielle(r, _propre(angles[k]))}',
    ].join(r'\,;\,');
  }
  // 0 n'a pas d'argument : Giac rend arg(0) = 0.
  if (r == '0') return '0';
  final theta = _propre(morceaux[1]);
  return forme == FormeComplexe.exponentielle
      ? _exponentielle(r, theta)
      : _trigonometrique(r, theta);
}

/// r e^{iθ} : `e^{i\frac{\pi}{4}}`, `e^{-i\frac{\pi}{4}}` ; r = 1 ne s'écrit
/// pas, θ = 0 laisse r seul.
String _exponentielle(String r, String theta) {
  if (theta == '0') return r;
  final negatif = theta.startsWith('-');
  final angle = negatif ? theta.substring(1) : theta;
  final puissance = 'e^{${negatif ? '-' : ''}i$angle}';
  return r == '1' ? puissance : '$r\\,$puissance';
}

/// r (cos θ + i sin θ), l'angle entre parenthèses s'il n'est pas simple.
String _trigonometrique(String r, String theta) {
  final simple = RegExp(r'^(\\pi|\d+|\\frac\{[^{}]*\}\{[^{}]*\})$');
  final angle = simple.hasMatch(theta)
      ? ' $theta'
      : r'\left('
            '$theta'
            r'\right)';
  final corps = '\\cos$angle+i\\sin$angle';
  return r == '1' ? corps : '$r\\left($corps\\right)';
}

/// `\frac{3\cdot \pi }{4}` → `\frac{3\pi}{4}` ; `\mathrm{atan}` → `\arctan`.
String _propre(String latex) => latex
    .trim()
    .replaceAll(RegExp(r'\\cdot\s*\\pi'), r'\pi')
    .replaceAll(RegExp(r'\\pi\s+'), r'\pi')
    .replaceAll(r'\mathrm{atan}', r'\arctan')
    .replaceAll(RegExp(r'\s+\}'), '}')
    .trim();

/// `[a,[b,c]]` → `a`, `[b,c]` (virgules hors accolades et crochets).
List<String>? _liste(String latex) {
  final t = latex.trim();
  if (!t.startsWith('[') || !t.endsWith(']')) return null;
  final dedans = t.substring(1, t.length - 1);
  final morceaux = <String>[];
  var profondeur = 0;
  var debut = 0;
  for (var i = 0; i < dedans.length; i++) {
    final c = dedans[i];
    if ('{[('.contains(c)) profondeur++;
    if ('}])'.contains(c)) profondeur--;
    if (c == ',' && profondeur == 0) {
      morceaux.add(dedans.substring(debut, i));
      debut = i + 1;
    }
  }
  morceaux.add(dedans.substring(debut));
  return morceaux.map((m) => m.trim()).toList();
}
