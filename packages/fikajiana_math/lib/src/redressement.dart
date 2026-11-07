/// Corrige ce que le modèle de lecture confond le plus sur une écriture réelle
/// (relevé sur le Pad 7, ADR 0026). Chaque règle ne touche qu'une écriture qui
/// n'aurait aucun sens en maths ; le résultat reste visible et corrigeable.
///
/// [fonctions] : les fonctions déjà définies au-dessus sur la feuille.
String redresserLecture(String latex, {Set<String> fonctions = const {}}) {
  var s = latex
      .replaceAll(RegExp(r'\\right\s*\.'), '')
      .replaceAll(RegExp(r'\\(?:left|right)\b'), '')
      .trim();
  s = _primes(s);
  s = _parentheseEnExposant(s);
  s = _tete(s, fonctions);
  s = _baseE(s);
  s = _matriceEnBinome(s);
  s = _teteDeDeterminant(s);
  s = _pointEnFraction(s);
  return s;
}

/// Les nombres d'une ligne : `2 5` donne 2 et 5, `- 1 - 3` donne -1 et -3.
List<String>? _nombres(String ligne) {
  final trouves = RegExp(r'(-\s*)?\d').allMatches(ligne);
  final reste = ligne.replaceAll(RegExp(r'[-\s\d]'), '');
  if (reste.isNotEmpty || trouves.isEmpty) return null;
  return [for (final m in trouves) m[0]!.replaceAll(' ', '')];
}

/// `\binom{2 5}{-1 -3}` : une matrice lue comme un coefficient binomial. Les
/// deux lignes ont autant de nombres et il y en a au moins deux, ce qu'un
/// binomial n'écrit presque jamais. `\binom{10}{2}` et `\binom{n}{k}` restent.
String _matriceEnBinome(String s) =>
    s.replaceAllMapped(RegExp(r'\\binom\s*\{([^{}]*)\}\s*\{([^{}]*)\}'), (m) {
      final (haut, bas) = (_nombres(m[1]!), _nombres(m[2]!));
      if (haut == null || bas == null) return m[0]!;
      if (haut.length != bas.length || haut.length < 2) return m[0]!;
      final lignes = [haut.join('&'), bas.join('&')].join(r'\\');
      return [r'\begin{pmatrix}', lignes, r'\end{pmatrix}'].join();
    });

/// `det` écrit à la main, lu `\alpha +`, `d e t` ou `d e t`, devant une matrice.
String _teteDeDeterminant(String s) => s.replaceFirstMapped(
  RegExp(
    r'^\s*(?:\\alpha\s*\+?|\\delta\s*\+?|d\s*e\s*t|\\det)\s*'
    r'(\(?\s*\\begin\{[a-z]*matrix\})',
  ),
  (m) => '\\det ${m[1]}',
);

/// `A(1/2)` : le point-virgule d'un point, lu comme une barre. Une lettre
/// capitale devant une fraction de deux nombres n'a pas d'autre sens courant.
String _pointEnFraction(String s) {
  final m = RegExp(
    r'^\s*([A-Z])\s*\(\s*(?:(-?\s*\d+)\s*/\s*(-?\s*\d+)'
    r'|\\frac\s*\{\s*(-?\s*\d+)\s*\}\s*\{\s*(-?\s*\d+)\s*\})\s*\)\s*$',
  ).firstMatch(s);
  if (m == null) return s;
  String net(String v) => v.replaceAll(' ', '');
  return '${m[1]}(${net(m[2] ?? m[4]!)};${net(m[3] ?? m[5]!)})';
}

const _exposantPrime = r"\^\s*\{?\s*(?:1|\\ell|l|I|\||\\prime|')\s*\}?";

/// `f^1(x)`, `f^{\ell}(x)` : l'apostrophe, lue comme un exposant. Une puissance
/// 1 d'une fonction n'aurait aucun intérêt à être écrite.
String _primes(String s) => s.replaceAllMapped(
  RegExp('\\b([fghkuv])\\s*$_exposantPrime\\s*(?=\\()'),
  (m) => "${m[1]}'",
);

/// `g^{(x)}`, `g^((x))` : le `(x)` écrit un peu haut, à cause de la queue du g.
String _parentheseEnExposant(String s) => s.replaceAllMapped(
  RegExp(
    r'\b([fgh])\s*\^\s*'
    r'(?:\{\s*\(\s*([a-z])\s*\)\s*\}|\(\s*\(\s*([a-z])\s*\)\s*\)|\(\s*([a-z])\s*\))',
  ),
  (m) => '${m[1]}(${m[2] ?? m[3] ?? m[4]})',
);

/// Les têtes confondues avec un `f` ou un `g` écrits à la main.
const _commeF = r'\\frac\s*\{\s*1\s*\}\s*\{\s*\d\s*\}|1\s*/\s*\d|7|4|1|\\ell';
const _commeG = '9|8|q';

/// `\frac{1}{4}(x)=e^x+2` : une fraction devant `(x)=` n'a pas de raison d'être
/// écrite ainsi ; c'est une définition si la suite dépend de x, ou si cette
/// fonction existe déjà.
String _tete(String s, Set<String> fonctions) {
  String? nom(String pour) => RegExp('^(?:$_commeF)\$').hasMatch(pour)
      ? 'f'
      : RegExp('^(?:$_commeG)\$').hasMatch(pour)
      ? 'g'
      : null;

  final avecPrime = RegExp(
    '^\\s*($_commeF|$_commeG)\\s*(?:'
    "'"
    '|$_exposantPrime)\\s*\\(\\s*([a-z])\\s*\\)(.*)\$',
    dotAll: true,
  ).firstMatch(s);
  if (avecPrime != null) {
    return "${nom(avecPrime[1]!)}'(${avecPrime[2]})${avecPrime[3]}";
  }

  final m = RegExp(
    '^\\s*($_commeF|$_commeG)\\s*\\(\\s*([a-z])\\s*\\)\\s*=(.*)\$',
    dotAll: true,
  ).firstMatch(s);
  if (m == null) return s;
  final lue = nom(m[1]!)!;
  final variable = m[2]!;
  final suite = m[3]!;
  final dependDeLaVariable = RegExp('(^|[^a-zA-Z\\\\])$variable')
      .hasMatch(suite);
  if (!dependDeLaVariable && !fonctions.contains(lue)) return s;
  return '$lue($variable)=$suite';
}

/// `5 0 ^ { x }` : le `e` lu comme un zéro. `10^x`, `100^x` restent.
String _baseE(String s) => s.replaceAllMapped(
  RegExp(r'(^|[^0-9.,])((?:[0-9]\s*)*)[0oO]\s*\^\s*(\{\s*[a-z]\s*\}|[a-z])'),
  (m) {
    final avant = m[2]!.replaceAll(' ', '');
    if (RegExp(r'^10*$').hasMatch(avant)) return m[0]!;
    return '${m[1]}$avant e^${m[3]}';
  },
);
