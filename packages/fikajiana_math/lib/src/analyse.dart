import 'package:fikajiana_math/src/arithmetique.dart';
import 'package:fikajiana_math/src/evaluateur.dart';
import 'package:fikajiana_math/src/lecteur_latex.dart';
import 'package:fikajiana_math/src/probabilites.dart';
import 'package:fikajiana_math/src/redressement.dart';
import 'package:fikajiana_math/src/statistiques.dart';

/// Ce que l'écriture semble être.
enum TypeExpression {
  /// Une valeur à calculer : `2+3`, `2+3=`, `\sin(\pi)`.
  calcul,

  /// Une équation à résoudre : `x^2=2`.
  equation,

  /// Un système à résoudre : accolade ou matrice de relations.
  systeme,

  /// Une fonction à définir : `f(x)=x^2`.
  fonction,

  /// Une matrice.
  matrice,

  /// Une suite définie par récurrence : `u_{n+1}=2u_n`.
  suite,
}

/// Résultat de l'analyse d'un LaTeX : son type et l'entrée à donner à Giac.
class Analyse {
  /// Crée une analyse.
  const new(
    this.type,
    this.giac, {
    this.inconnues = const [],
    this.corps,
    this.membres,
    this.nomFonction,
    this.nomValeur,
    this.demandeResultat = false,
    this.inconnueMatrice,
    this.variableFonction,
  });

  /// La variable de [nomFonction] quand elle n'est pas l'inconnue : `n` pour
  /// le terme général `w_n` d'une suite récurrente.
  final String? variableFonction;

  /// `X` pour `AX=B` : l'inconnue d'une équation matricielle, que [giac]
  /// calcule directement (`A^{-1}B`). Le résultat s'écrit `X = …`.
  final String? inconnueMatrice;

  /// Type deviné.
  final TypeExpression type;

  /// Entrée Giac.
  final String giac;

  /// Le corps d'une fonction, `x^2` pour `f(x)=x^2`, à évaluer ou à tracer.
  final String? corps;

  /// Ce que Giac résout, dans l'ordre de ses solutions ; la variable d'une
  /// fonction.
  final List<String> inconnues;

  /// Les deux membres d'une équation, traduits pour Giac.
  final (String, String)? membres;

  /// `a` pour `a=2` : sa valeur est [giac], à retenir pour les lignes
  /// suivantes.
  final String? nomValeur;

  /// `f` pour `f(x)=x^2`, à retenir pour les lignes suivantes.
  final String? nomFonction;

  /// La réponse s'affiche même sans `=` : `f'(x)`, `det(…)`.
  final bool demandeResultat;

  /// Pour les lignes suivantes, si c'est une définition.
  DefinitionFonction? get definition => nomFonction == null
      ? null
      : DefinitionFonction(
          variable: variableFonction ?? inconnues.single,
          corps: corps!,
        );
}

/// Une fonction définie plus haut sur la feuille : `f(x)=x+5`.
class DefinitionFonction {
  /// Crée la définition.
  const new({
    required this.variable,
    required this.corps,
    this.symboles = const {},
  });

  /// Sa variable, `x`.
  final String variable;

  /// Son corps, traduit pour Giac.
  final String corps;

  /// Les lettres de son corps.
  final Set<String> symboles;

  /// `f(2)`, ou `f'(2)` pour [primes] à 1, traduit pour Giac.
  String appel(String argument, {int primes = 0}) {
    if (primes == 0) {
      if (argument == variable) return '($corps)';
      return '(${corps.replaceAll(RegExp('\\b$variable\\b'), '($argument)')})';
    }
    final derivee = primes == 1
        ? 'diff($corps,$variable)'
        : 'diff($corps,$variable,$primes)';
    // `normal` : Giac rendait `3*x^2-3*2*x` pour la dérivée de
    // `x^3-3x^2+2` (banc de la feuille, Pad 7).
    return argument == variable
        ? 'normal($derivee)'
        : 'subst($derivee,$variable=$argument)';
  }
}

/// Le LaTeX n'a pas pu être compris.
class ErreurLatex implements Exception {
  /// Crée l'erreur.
  const new(this.message);

  /// Détail, pour le débogage.
  final String message;

  @override
  String toString() => 'ErreurLatex: $message';
}

/// Analyse un LaTeX lu ou corrigé, et le traduit pour Giac.
///
/// [degres] : Giac compte en degrés ; `30°` reste donc `30`.
///
/// Lève [ErreurLatex] si le texte n'est pas compris : aucun résultat deviné.
///
/// [definitions] : les fonctions écrites plus haut sur la feuille. `f'(x)` est
/// alors sa dérivée, et `f(x)=0` une équation.
Analyse analyserLatex(
  String latex, {
  bool degres = false,
  Map<String, DefinitionFonction> definitions = const {},
  Map<String, (double, double)> points = const {},
  Map<String, (double, double)> vecteurs = const {},
  Map<String, String> valeurs = const {},
}) {
  // `A_5^2` : les arrangements du lycée (vague 2).
  final arrangements = avecArrangements(latex);
  if (arrangements != latex) {
    return analyserLatex(
      arrangements,
      degres: degres,
      definitions: definitions,
      points: points,
      vecteurs: vecteurs,
      valeurs: valeurs,
    );
  }
  // `ajustement([x];[y])`, `quartiles(…)` (vague 3).
  final statistiques = analyserStatistiques(latex, valeurs: valeurs);
  if (statistiques != null) return statistiques;
  // `division(17;5)`, `17 \equiv 2 [5]` (vague 2).
  final arithmetique = analyserArithmetique(latex, valeurs: valeurs);
  if (arithmetique != null) return arithmetique;
  // `X \sim B(10;0{,}3)`, puis `P(X\le3)=`, `E(X)=` (ADR 0052).
  final loi =
      analyserLoi(latex, valeurs: valeurs) ??
      analyserProbabilite(latex, valeurs: valeurs);
  if (loi != null) return loi;
  // `y'-3y=cos(x)` : une équation différentielle (feuille d'Antsa, Pad 7).
  final differentielle = _equationDifferentielle(latex, degres: degres);
  if (differentielle != null) return differentielle;
  // `résoudre(f(x)=k(x))`, `résoudre(x^2-4)` : l'équation entre parenthèses
  // (feuille d'Antsa, Pad 7) ; sans `=`, l'expression vaut 0.
  final resoudre = RegExp(
    r'^\s*(?:\\(?:operatorname\*?|mathrm|mathit|rm|text|textrm|textit)'
    r'\s*\{\s*)?(?:r[ée]soudre|resoudre|solve)\s*\}?\s*\((.*)\)\s*=?\s*$',
    dotAll: true,
  ).firstMatch(sansLeftRight(latex));
  if (resoudre != null) {
    final dedans = resoudre[1]!.trim();
    return analyserLatex(
      RegExp(r'=|<|>|\\(?:leq|geq|le|ge|lt|gt)').hasMatch(dedans)
          ? dedans
          : '$dedans=0',
      degres: degres,
      definitions: definitions,
      points: points,
      vecteurs: vecteurs,
      valeurs: valeurs,
    );
  }
  final lecteur = LecteurLatex(
    latex,
    degres: degres,
    definitions: definitions,
    points: points,
    vecteurs: vecteurs,
    valeurs: valeurs,
  );
  final lecture = lecteur.lire();
  final suite = lecteur.suite;
  if (suite != null) return _analyserSuite(lecture, suite, valeurs);
  final demande = lecteur.demandeResultat;

  if (lecture is LectureSysteme) {
    final inconnues = <String>{};
    for (final relation in lecture.relations) {
      inconnues.addAll(relation.symboles);
    }
    final variables = _ordonner(inconnues);
    final relations = lecture.relations.map((r) => r.giac).join(',');
    return Analyse(
      TypeExpression.systeme,
      'solve([$relations],[${variables.join(',')}])',
      inconnues: variables,
    );
  }

  final expression = lecture as LectureExpression;
  final droite = expression.droite;
  if (!expression.aEgal) {
    return Analyse(
      expression.gauche.estMatrice
          ? TypeExpression.matrice
          : TypeExpression.calcul,
      expression.gauche.giac,
      demandeResultat: demande,
    );
  }
  if (droite == null) {
    return Analyse(
      TypeExpression.calcul,
      expression.gauche.giac,
      demandeResultat: demande,
    );
  }

  final definition = expression.gauche.definitionDeFonction;
  // `f` est déjà définie : `f(x)=0` est une équation, `f(x)=2x` la redéfinit.
  // `f(x)=k(x)`, f et k définies plus haut : une équation aussi (feuille
  // d'Antsa, Pad 7), pas une nouvelle définition de f.
  final aDroite = latex.substring(latex.indexOf('=') + 1);
  final appelleUneFonction = definitions.keys.any(
    (nom) =>
        RegExp('(?<![a-zA-Z\\\\])$nom\\s*(?:\\\\left)?\\s*\\(')
            .hasMatch(aDroite),
  );
  final estEquation =
      expression.gauche.fonctionDefinie &&
      (droite.symboles.isEmpty || appelleUneFonction);
  if (definition != null && !estEquation) {
    final variable = definition.substring(
      definition.indexOf('(') + 1,
      definition.length - 1,
    );
    return Analyse(
      TypeExpression.fonction,
      '$definition:=${droite.giac}',
      inconnues: [variable],
      corps: droite.giac,
      nomFonction: definition.substring(0, definition.indexOf('(')),
    );
  }
  // `u_n=2n+3` : une suite donnée par son terme général, définie comme une
  // fonction de n pour les lignes suivantes (`u_{10}=`, une somme).
  final explicite = RegExp(r'^([a-zA-Z])_([a-z])$')
      .firstMatch(expression.gauche.giac);
  if (explicite != null &&
      droite.symboles.contains(explicite[2]) &&
      !droite.symboles.contains(expression.gauche.giac)) {
    final (nom, rang) = (explicite[1]!, explicite[2]!);
    return Analyse(
      TypeExpression.fonction,
      '$nom($rang):=${droite.giac}',
      inconnues: [rang],
      corps: droite.giac,
      nomFonction: nom,
    );
  }
  // `a=2` : une valeur pour les lignes suivantes. x, y, z, t, r et θ restent
  // des inconnues (choix d'Antsa, ADR 0024). `w_0=2` aussi : le premier
  // terme d'une suite écrite dessous.
  if ((RegExp(r'^[a-df-hj-qsu-wA-Z]$').hasMatch(expression.gauche.giac) ||
          RegExp(r'^[a-zA-Z]_\d+$').hasMatch(expression.gauche.giac)) &&
      droite.symboles.isEmpty) {
    return Analyse(
      TypeExpression.calcul,
      droite.giac,
      nomValeur: expression.gauche.giac,
    );
  }
  // `y=2x+1` : une courbe à tracer, pas une équation d'inconnue x.
  if (expression.gauche.giac == 'y' &&
      droite.symboles.length == 1 &&
      !droite.symboles.contains('y')) {
    final variable = droite.symboles.single;
    return Analyse(
      TypeExpression.fonction,
      'y($variable):=${droite.giac}',
      inconnues: [variable],
      corps: droite.giac,
      nomFonction: 'y',
    );
  }
  final symboles = {...expression.gauche.symboles, ...droite.symboles};
  final ordre = expression.ordre;
  if (ordre != null) {
    final relation = '${expression.gauche.giac}$ordre${droite.giac}';
    if (symboles.isEmpty) return Analyse(TypeExpression.calcul, relation);
    final variable = _ordonner(symboles).first;
    return Analyse(
      TypeExpression.equation,
      'solve($relation,$variable)',
      inconnues: [variable],
    );
  }
  if (symboles.isEmpty) {
    return Analyse(
      TypeExpression.calcul,
      'normal((${expression.gauche.giac})-(${droite.giac}))==0',
    );
  }
  final matricielle = _equationMatricielle(
    expression.gauche.giac,
    droite.giac,
    vecteurs,
  );
  if (matricielle != null) return matricielle;
  final variable = _ordonner(symboles).first;
  return Analyse(
    TypeExpression.equation,
    'solve(${expression.gauche.giac}=${droite.giac},$variable)',
    inconnues: [variable],
    membres: (expression.gauche.giac, droite.giac),
  );
}

/// `y' - 3y = \cos(x)`, `y'' + y = 0` : y fonction de x (ou de t), sans
/// `y(` écrit ; le modèle lit `y^{1}` pour `y'`. Giac la résout
/// (`desolve`), constantes comprises ; `null` si ce n'en est pas une.
Analyse? _equationDifferentielle(String ecrit, {required bool degres}) {
  // `y'(t)` et `y(t)` : la variable écrite, qu'on retire.
  final avecVariable = RegExp(
    r"(?<![a-zA-Z\\])(y\s*(?:'+|\^\s*\{?\s*(?:\\prime\s*)+\}?)?)\s*\(\s*([xt])\s*\)",
  );
  final primeEcrit = RegExp(r"(?<![a-zA-Z\\])y\s*(?:'|\^\s*\{?\s*\\prime)")
      .hasMatch(ecrit);
  final latex = primeEcrit
      ? ecrit.replaceAllMapped(avecVariable, (m) => m[1]!)
      : ecrit;
  if (RegExp(r'(?<![a-zA-Z\\])y\s*\(').hasMatch(latex)) return null;
  const libre = r'(?<![a-zA-Z\\])y\s*';
  final seconde = RegExp(
    libre + r"(?:''|\^\s*\{\s*(?:\\prime\s*\\prime|'')\s*\})",
  );
  final premiere = RegExp(
    libre + r"(?:'|\^\s*\{?\s*(?:\\prime|'|1(?!\d))\s*\}?)",
  );
  if (!premiere.hasMatch(latex) && !seconde.hasMatch(latex)) return null;
  final ordre2 = seconde.hasMatch(latex);
  final texte = latex
      .replaceAll(seconde, r' \phi ')
      .replaceAll(premiere, r' \mu ');
  final Analyse a;
  try {
    a = analyserLatex(texte, degres: degres);
  } on ErreurLatex {
    return null;
  }
  final (gauche, droite) = a.membres ?? (a.giac, '0');
  final ensemble = '$gauche $droite';
  final v =
      RegExp(r'\bt\b').hasMatch(ensemble) &&
          !RegExp(r'\bx\b').hasMatch(ensemble)
      ? 't'
      : 'x';
  String fonction(String s) => s
      .replaceAll(RegExp(r'\by\b'), 'y($v)')
      .replaceAll(RegExp(r'\bmu\b'), 'diff(y($v),$v)')
      .replaceAll(RegExp(r'\bphi\b'), 'diff(y($v),$v,2)');
  if (ordre2) {
    return _secondOrdre('($gauche)-($droite)', v);
  }
  return Analyse(
    TypeExpression.calcul,
    'y($v)=desolve((${fonction(gauche)})=(${fonction(droite)}),y($v))',
    demandeResultat: true,
  );
}

/// `a·y'' + b·y' + c·y = f(x)`, a, b, c constants : `desolve` du second ordre
/// fait tomber Giac sur l'appareil (récursion sans fin dans `operator_minus`,
/// même pour `y''+y=0`, banc du Pad 7). La solution s'écrit ici : équation
/// caractéristique, puis une solution particulière par variation des
/// constantes, que Giac intègre. Le reste est refusé.
Analyse _secondOrdre(String p, String v) {
  // [p] s'écrit avec `phi` (y''), `mu` (y'), `y` ; P(φ, μ, ψ) en x.
  String en(num phi, num mu, num y) => p
      .replaceAll(RegExp(r'\bphi\b'), '($phi)')
      .replaceAll(RegExp(r'\bmu\b'), '($mu)')
      .replaceAll(RegExp(r'\by\b'), '($y)');
  double val(String g, double x) {
    try {
      return compilerFonction(g, variable: v)(x);
    } on ErreurEvaluation {
      throw const ErreurLatex('équation différentielle non lue');
    }
  }

  double coef(num phi, num mu, num y, double x) =>
      val(en(phi, mu, y), x) - val(en(0, 0, 0), x);
  const xs = [0.37, 1.61];
  final (a, b, c) = (
    coef(1, 0, 0, xs[0]),
    coef(0, 1, 0, xs[0]),
    coef(0, 0, 1, xs[0]),
  );
  // Linéaire, à coefficients constants : sinon, pas de formule.
  for (final x in xs) {
    final ok = [
      (coef(1, 0, 0, x) - a).abs(),
      (coef(0, 1, 0, x) - b).abs(),
      (coef(0, 0, 1, x) - c).abs(),
      (coef(2, 0, 0, x) - 2 * a).abs(),
      (coef(0, 2, 0, x) - 2 * b).abs(),
      (coef(0, 0, 2, x) - 2 * c).abs(),
      (coef(1, 1, 1, x) - a - b - c).abs(),
    ].every((e) => e < 1e-9);
    if (!ok || a.abs() < 1e-12) {
      throw const ErreurLatex('équation différentielle non linéaire');
    }
  }
  final (ra, rb, rc) = (_rationnel(a), _rationnel(b), _rationnel(c));
  if (ra == null || rb == null || rc == null) {
    throw const ErreurLatex('coefficients non rationnels');
  }
  final d = b * b - 4 * a * c;
  final alpha = 'normal(-($rb)/(2*($ra)))';
  final String y1;
  final String y2;
  if (d.abs() < 1e-12) {
    y1 = 'exp($alpha*$v)';
    y2 = '$v*exp($alpha*$v)';
  } else if (d > 0) {
    final racine = 'sqrt(($rb)^2-4*($ra)*($rc))';
    y1 = 'exp(normal((-($rb)+$racine)/(2*($ra)))*$v)';
    y2 = 'exp(normal((-($rb)-$racine)/(2*($ra)))*$v)';
  } else {
    final beta = 'normal(sqrt(4*($ra)*($rc)-($rb)^2)/(2*abs($ra)))';
    y1 = 'exp($alpha*$v)*cos($beta*$v)';
    y2 = 'exp($alpha*$v)*sin($beta*$v)';
  }
  // Le second membre : f = −P(0, 0, 0).
  final f = '-(${en(0, 0, 0)})';
  final homogene = 'c_0*($y1)+c_1*($y2)';
  final constant =
      (val(en(0, 0, 0), xs[0]) - val(en(0, 0, 0), xs[1])).abs() < 1e-12 &&
      val(en(0, 0, 0), xs[0]).abs() < 1e-12;
  if (constant) {
    return Analyse(
      TypeExpression.calcul,
      'y($v)=$homogene',
      demandeResultat: true,
    );
  }
  final w = '(($y1)*diff($y2,$v)-diff($y1,$v)*($y2))';
  final particuliere =
      '-($y1)*integrate(($y2)*($f)/(($ra)*$w),$v)'
      '+($y2)*integrate(($y1)*($f)/(($ra)*$w),$v)';
  return Analyse(
    TypeExpression.calcul,
    'y($v)=$homogene+simplify($particuliere)',
    demandeResultat: true,
  );
}

/// [x] en fraction simple, `(n/d)` avec d ≤ 24 ; `null` sinon.
String? _rationnel(double x) {
  for (var d = 1; d <= 24; d++) {
    final n = (x * d).round();
    if ((x * d - n).abs() < 1e-9) return d == 1 ? '($n)' : '($n/$d)';
  }
  return null;
}

/// `u_{n+1}=a·u_n+b`, avec ou sans `u_0=1` dans un système : le terme général
/// s'écrit directement. Pas de `rsolve` : sur `u_{n+2}=3u_{n+1}-2u_n`, Giac ne
/// rend jamais la main, même arrêté (banc, ADR 0026). Le reste est refusé.
Analyse _analyserSuite(
  Lecture lecture,
  String nom,
  Map<String, String> valeurs,
) {
  final relations = switch (lecture) {
    LectureSysteme(:final relations) => [for (final r in relations) r.giac],
    LectureExpression(:final gauche, :final droite?, ordre: null) => [
      '${gauche.giac}=${droite.giac}',
    ],
    _ => throw const ErreurLatex('suite sans égalité'),
  };
  final terme = RegExp('\\b${nom}_([a-zA-Z0-9]+)\\b');
  final claires = [
    for (final r in relations)
      r.replaceAllMapped(terme, (m) => '$nom(${m[1]})'),
  ];
  final depart = RegExp('^$nom\\((\\d+)\\)=(.*)\$');
  final departs = claires.map(depart.firstMatch).nonNulls.toList();
  final recurrences = claires.where((r) => !depart.hasMatch(r)).toList();
  if (recurrences.length != 1 || departs.length > 1) {
    throw const ErreurLatex('une récurrence et un premier terme');
  }
  final avancee = RegExp('^$nom\\(([a-z])\\+1\\)=(.*)\$')
      .firstMatch(recurrences.single);
  final reculee = RegExp('^$nom\\(([a-z])\\)=(.*)\$')
      .firstMatch(recurrences.single);
  final egalite = avancee ?? reculee;
  if (egalite == null) throw const ErreurLatex('récurrence non reconnue');
  final rang = egalite[1]!;
  final precedent = RegExp(
    avancee != null ? '\\b$nom\\($rang\\)' : '\\b$nom\\($rang-1\\)',
  );
  final corps = egalite[2]!.replaceAll(precedent, '(w)');
  // Un autre terme, `u_{n-2}` : la suite n'est pas d'ordre 1.
  if (RegExp('\\b$nom\\(').hasMatch(corps)) {
    throw const ErreurLatex('suite d’ordre supérieur à 1');
  }
  final (a, unite) = _coefficient(corps, rang);
  final b = 'subst($corps,w=0)';
  // Sans premier terme sur la ligne : celui écrit plus haut (`w_0=2`), le
  // plus petit rang d'abord.
  final retenus = [
    for (final MapEntry(:key) in valeurs.entries)
      if (RegExp('^${nom}_(\\d+)\$').firstMatch(key) case final m?)
        int.parse(m[1]!),
  ]..sort();
  final premier = departs.isNotEmpty
      ? departs.single[1]!
      : retenus.isNotEmpty
      ? '${retenus.first}'
      : '0';
  final valeur = departs.isNotEmpty
      ? '(${departs.single[2]})'
      : retenus.isNotEmpty
      ? '(${valeurs['${nom}_$premier']})'
      : '${nom}_$premier';
  final ecart = '($rang-$premier)';
  final general = unite
      ? 'normal($valeur+($b)*$ecart)'
      : 'normal(($a)^$ecart*($valeur-($b)/(1-($a)))+($b)/(1-($a)))';
  // Le terme général sert aux lignes suivantes : `w_3=`, une somme.
  return Analyse(
    TypeExpression.suite,
    general,
    inconnues: ['${nom}_$rang'],
    corps: general,
    nomFonction: nom,
    variableFonction: rang,
  );
}

/// Le coefficient `a` de `a·w+b`, et s'il vaut 1. Vérifie à l'évaluation que
/// [corps] est bien de cette forme, sans le rang : sinon, pas de formule.
(String, bool) _coefficient(String corps, String rang) {
  final FonctionDeuxVariables f;
  try {
    f = compilerFonctionXY(
      corps
          .replaceAll(RegExp(r'\bw\b'), 'x')
          .replaceAll(RegExp('\\b$rang\\b'), 'y'),
    );
    const y1 = 1.3;
    const y2 = 2.7;
    final a = f(1, y1) - f(0, y1);
    final proche = (a - (f(3, y1) - f(2, y1))).abs() < 1e-9;
    final sansRang = (f(1, y1) - f(1, y2)).abs() < 1e-9;
    if (!a.isFinite || !proche || !sansRang) {
      throw const ErreurLatex('suite non affine');
    }
    return ('diff($corps,w)', (a - 1).abs() < 1e-12);
  } on ErreurEvaluation {
    throw const ErreurLatex('suite avec une lettre inconnue');
  }
}

/// `AX=B`, `A\cdot X=B`, avec A une matrice de la feuille et B une matrice,
/// un vecteur colonne ou un vecteur `\vec{B}` : X = A⁻¹B, si A est
/// inversible (sinon Giac le dit). `XA=B` : X = BA⁻¹.
Analyse? _equationMatricielle(
  String gauche,
  String droite,
  Map<String, (double, double)> vecteurs,
) {
  String? sansParentheses(String s) {
    var t = s.trim();
    while (t.startsWith('(') && t.endsWith(')')) {
      t = t.substring(1, t.length - 1).trim();
    }
    return t.startsWith('[[') && t.endsWith(']]') ? t : null;
  }

  final produit =
      RegExp(r'^(.*)\*([A-Z])$').firstMatch(gauche) ??
      RegExp(r'^([A-Z])\*(.*)$').firstMatch(gauche);
  if (produit == null) return null;
  final aGauche = RegExp(r'^[A-Z]$').hasMatch(produit[2]!);
  final inconnue = aGauche ? produit[2]! : produit[1]!;
  final matrice = sansParentheses(aGauche ? produit[1]! : produit[2]!);
  if (matrice == null) return null;
  var second = droite.trim();
  // `(([[5],[6]]))` d'une matrice déclarée : la matrice seule.
  final seule = RegExp(r'^\(+(\[\[[^()]*\]\])\)+$').firstMatch(second);
  if (seule != null) second = seule[1]!;
  final vecteur = vecteurs[second];
  if (vecteur != null) {
    second = '[[${_nombreGiac(vecteur.$1)}],[${_nombreGiac(vecteur.$2)}]]';
  }
  if (!second.contains('[') || RegExp('[a-zA-Z]').hasMatch(second)) {
    return null;
  }
  return Analyse(
    TypeExpression.calcul,
    aGauche ? 'inv($matrice)*($second)' : '($second)*inv($matrice)',
    inconnueMatrice: inconnue,
    demandeResultat: true,
  );
}

String _nombreGiac(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';

/// Inconnues usuelles d'abord : x, y, z, t, puis l'ordre alphabétique.
List<String> _ordonner(Set<String> symboles) {
  const usuelles = ['x', 'y', 'z', 't'];
  return [
    ...usuelles.where(symboles.contains),
    ...symboles.where((s) => !usuelles.contains(s)).toList()..sort(),
  ];
}
