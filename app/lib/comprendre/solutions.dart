import 'package:fikajiana_math/fikajiana_math.dart';

/// Écrit les solutions rendues par Giac comme on les écrit au tableau :
/// `x = 1`, `x = -2 ou x = 2`, `S = ∅`. Jamais `x+3=4 = {1}`, qui est faux.
///
/// Ce qui n'a pas la forme attendue reste tel quel : rien n'est deviné.
String ecrireSolutions(
  String latex, {
  required TypeExpression type,
  required List<String> inconnues,
  required bool francais,
}) {
  if (inconnues.isEmpty) return latex;
  // Giac nomme ses entiers n_0, n_1… : `sin(x)=0` a une infinité de solutions.
  final propre = latex.replaceAll(RegExp(r'\\mathrm\{n\\_\d+\}'), 'n');
  final suite = propre == latex ? '' : r',\,n \in \mathbb{Z}';
  final texte = propre.trim();
  // Le terme général, déjà écrit : il suffit de le nommer.
  // Giac écrit `\mathrm{u\_0}` le premier terme laissé sans valeur.
  if (type == TypeExpression.suite) {
    final termes = texte.replaceAllMapped(
      RegExp(r'\\mathrm\{([a-zA-Z])\\_(\w+)\}'),
      (m) => '${m[1]}_{${m[2]}}',
    );
    return '${inconnues.first}=$termes';
  }
  if (texte == '[]' || texte == '' || texte == r'\{\}') return r'S=\emptyset';

  final ou =
      r'\,\mathrm{'
      '${francais ? 'ou' : 'or'}'
      r'}\,';
  final String? solutions;
  if (type == TypeExpression.systeme) {
    solutions = _systeme(texte, inconnues, francais ? 'et' : 'and', ou);
  } else {
    solutions = _equation(texte, inconnues.first, ou);
  }
  return solutions == null ? latex : '$solutions$suite';
}

/// Vrai si la ligne pose une question qu'une réponse équivalente résout :
/// une relation (`=`, `<`, `≤`…) ou `résoudre(…)`. `division(17;5)` ou
/// `ajustement(…)` ne sont pas équivalents à `q=3 et r=2` : pas de `⇔`.
bool poseUneRelation(String latex) => RegExp(
  r'[=<>]|\\(le|ge|leq|geq|leqslant|geqslant|neq|ne)(?![a-zA-Z])'
  r'|r[ée]soudre|\bsolve',
).hasMatch(latex);

String? _equation(String texte, String inconnue, String ou) {
  if (!texte.startsWith(r'\{') || !texte.endsWith(r'\}')) return null;
  final valeurs = _separer(texte.substring(2, texte.length - 2), ',');
  final nom = _nom(inconnue);
  if (valeurs.any(_estRelation.hasMatch)) {
    return valeurs.map(_inequation).join(ou);
  }
  if (valeurs.length == 1 && valeurs.single == inconnue) {
    return r'S=\mathbb{R}';
  }
  return valeurs.map((v) => '$nom=$v').join(ou);
}

final _estRelation = RegExp(r'[<>]|\\leq|\\geq');

/// Giac rend `(x>\mathrm{-2})\mbox{ and }(x<2)` : on écrit `-2<x<2`.
String _inequation(String relation) {
  final propre = relation
      .replaceAllMapped(RegExp(r'\\mathrm\{(-[^{}]*)\}'), (m) => m[1]!)
      // `x>(e)` : une borne seule n'a pas besoin de parenthèses. Celles d'une
      // fonction (`\ln(3)`) restent : une lettre les précède.
      .replaceAllMapped(
        RegExp(r'(?<![a-zA-Z\\])\((\w+|\\[a-zA-Z]+) ?\)'),
        (m) => m[1]!,
      );
  final deux = RegExp(
    r'^\((.+?)(>|\\geq )(.+?)\)\\mbox\{ and \}\(\1(<|\\leq )(.+?)\)$',
  ).firstMatch(propre);
  if (deux == null) return propre;
  String signe(String s) => s.trim() == '>'
      ? '<'
      : s.trim() == r'\geq'
      ? r'\leq '
      : s;
  return '${deux[3]}${signe(deux[2]!)}${deux[1]}${deux[4]}${deux[5]}';
}

String? _systeme(String texte, List<String> inconnues, String et, String ou) {
  final tableau = RegExp(
    r'\\begin\{array\}\{[^}]*\}(.*)\\end\{array\}',
    dotAll: true,
  ).firstMatch(texte);
  if (tableau == null) return null;
  final lignes = <String>[];
  for (final ligne in tableau[1]!.split(r'\\')) {
    if (ligne.trim().isEmpty) continue;
    final valeurs = _separer(ligne, '&');
    if (valeurs.length != inconnues.length) return null;
    lignes.add(
      [
        for (var i = 0; i < valeurs.length; i++)
          '${_nom(inconnues[i])}=${valeurs[i]}',
      ].join(
        r'\,\mathrm{'
        '$et'
        r'}\,',
      ),
    );
  }
  return lignes.isEmpty ? null : lignes.join(ou);
}

/// `theta` s'écrit `\theta` ; `x` et `x_1` restent tels quels.
String _nom(String inconnue) =>
    RegExp(r'^[a-zA-Z]{2,}$').hasMatch(inconnue) ? '\\$inconnue' : inconnue;

/// Coupe sur [separateur] hors de toute accolade ou parenthèse.
List<String> _separer(String texte, String separateur) {
  final morceaux = <String>[];
  var profondeur = 0;
  var debut = 0;
  for (var i = 0; i < texte.length; i++) {
    final c = texte[i];
    if ('{(['.contains(c)) profondeur++;
    if ('})]'.contains(c)) profondeur--;
    if (c == separateur && profondeur == 0) {
      morceaux.add(texte.substring(debut, i).trim());
      debut = i + 1;
    }
  }
  morceaux.add(texte.substring(debut).trim());
  return morceaux;
}
