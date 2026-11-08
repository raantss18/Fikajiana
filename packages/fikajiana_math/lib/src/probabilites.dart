/// Les lois de probabilité du lycée, écrites comme au tableau (vague 1 de
/// `docs/recherche/couverture-calcul.md`) :
///
/// - `X \sim B(10;0{,}3)` déclare X (binomiale, normale `N(\mu;\sigma^2)`,
///   Poisson `P(\lambda)`, géométrique `G(p)`, exponentielle `E(\lambda)`,
///   uniforme `U(a;b)`) pour les lignes suivantes ;
/// - `P(X=3)=`, `P(X\le 3)=`, `P(2\le X<5)=`, `P(X>1{,}5)=` ;
/// - `E(X)=`, `V(X)=`, `\sigma(X)=` ;
/// - le seuil : `P(X\le t)=0{,}95` (loi continue), `P(X\le k)\ge 0{,}95`
///   (plus petit entier k), `P(X\ge t)=0{,}05`.
///
/// Les probabilités discrètes s'écrivent comme une somme de termes, sans
/// dépendre des fonctions de répartition de Giac ; les quantiles passent par
/// `*_icdf` (doc Giac : <https://www-fourier.univ-grenoble-alpes.fr/~parisse/giac/doc/fr/cascmd_fr/cascmd_fr768.html>).
library;

import 'package:fikajiana_math/src/analyse.dart';
import 'package:fikajiana_math/src/redressement.dart' show sansLeftRight;

/// Une loi de probabilité du lycée.
enum GenreLoi {
  /// B(n ; p), sur 0…n.
  binomiale,

  /// N(μ ; σ²) : le second paramètre est la variance, comme au lycée.
  normale,

  /// P(λ), sur 0, 1, 2…
  poisson,

  /// G(p) : rang du premier succès, sur 1, 2, 3…
  geometrique,

  /// E(λ), sur [0 ; +∞[.
  exponentielle,

  /// U(a ; b), sur [a ; b].
  uniforme,
}

/// Une variable aléatoire déclarée : sa loi et ses paramètres, en Giac.
class Loi {
  /// Crée une loi.
  const new(this.genre, this.parametres);

  /// La loi gardée dans les valeurs de la feuille : `§loi§binomiale§10§0.3`.
  /// Le `§` n'est pas du Giac : une ligne qui ferait de X un nombre échoue au
  /// lieu de calculer faux.
  static Loi? lire(String? valeur) {
    if (valeur == null || !valeur.startsWith(_marque)) return null;
    final morceaux = valeur.substring(_marque.length).split('§');
    final genre = GenreLoi.values
        .where((g) => g.name == morceaux.first)
        .firstOrNull;
    if (genre == null) return null;
    return Loi(genre, morceaux.sublist(1));
  }

  static const _marque = '§loi§';

  /// La loi.
  final GenreLoi genre;

  /// Ses paramètres, en Giac, dans l'ordre écrit.
  final List<String> parametres;

  /// Ce que la feuille garde pour X.
  String get valeur => '$_marque${genre.name}§${parametres.join('§')}';

  /// Une loi à valeurs entières.
  bool get discrete => switch (genre) {
    GenreLoi.binomiale || GenreLoi.poisson || GenreLoi.geometrique => true,
    _ => false,
  };

  String _p(int i) => '(${parametres[i]})';

  /// P(X = j), j étant le nom d'une variable Giac.
  String _terme(String j) => switch (genre) {
    GenreLoi.binomiale =>
      'comb(${_p(0)},$j)*${_p(1)}^$j*(1-${_p(1)})^(${_p(0)}-$j)',
    GenreLoi.poisson => 'exp(-${_p(0)})*${_p(0)}^$j/factorial($j)',
    GenreLoi.geometrique => '(1-${_p(0)})^($j-1)*${_p(0)}',
    _ => throw StateError('loi continue'),
  };

  /// La plus petite valeur prise.
  int get _min => genre == GenreLoi.geometrique ? 1 : 0;

  /// La plus grande, ou `null` (pas de borne) ; seulement si n est un entier
  /// écrit.
  int? get _max =>
      genre == GenreLoi.binomiale ? int.tryParse(parametres[0].trim()) : null;

  /// P(X ≤ x), x en Giac (loi continue).
  String _repartition(String x) => switch (genre) {
    GenreLoi.normale => '(1+erf(($x-${_p(0)})/sqrt(2*${_p(1)})))/2',
    GenreLoi.exponentielle => '(1-exp(-${_p(0)}*max($x,0)))',
    GenreLoi.uniforme => 'min(1,max(0,($x-${_p(0)})/(${_p(1)}-${_p(0)})))',
    _ => throw StateError('loi discrète'),
  };

  /// L'espérance.
  String get esperance => switch (genre) {
    GenreLoi.binomiale => '${_p(0)}*${_p(1)}',
    GenreLoi.poisson => _p(0),
    GenreLoi.geometrique => '1/${_p(0)}',
    GenreLoi.normale => _p(0),
    GenreLoi.exponentielle => '1/${_p(0)}',
    GenreLoi.uniforme => '(${_p(0)}+${_p(1)})/2',
  };

  /// La variance.
  String get variance => switch (genre) {
    GenreLoi.binomiale => '${_p(0)}*${_p(1)}*(1-${_p(1)})',
    GenreLoi.poisson => _p(0),
    GenreLoi.geometrique => '(1-${_p(0)})/${_p(0)}^2',
    GenreLoi.normale => _p(1),
    GenreLoi.exponentielle => '1/${_p(0)}^2',
    GenreLoi.uniforme => '(${_p(1)}-${_p(0)})^2/12',
  };

  /// P(bas ≤ X ≤ haut) pour une loi discrète, bornes entières déjà
  /// arrondies (`null` : pas de borne).
  String probabiliteEntre(int? bas, int? haut) {
    final debut = bas == null || bas < _min ? _min : bas;
    final max = _max;
    final fin = haut == null
        ? max
        : max == null
        ? haut
        : (haut < max ? haut : max);
    if (fin != null && fin < debut) return '0';
    if (fin != null) return 'sum(${_terme('j')},j,$debut,$fin)';
    // Jusqu'à l'infini : le complément.
    if (debut <= _min) return '1';
    return '1-sum(${_terme('j')},j,$_min,${debut - 1})';
  }

  /// P(a ≤ X ≤ b) pour une loi continue, bornes en Giac (`null` : ∞).
  String probabiliteContinue(String? bas, String? haut) {
    final h = haut == null ? '1' : _repartition(haut);
    final b = bas == null ? '0' : _repartition(bas);
    return '($h)-($b)';
  }

  /// Le plus petit x tel que P(X ≤ x) ≥ α (loi discrète), ou le x tel que
  /// P(X ≤ x) = α (loi continue).
  String quantile(String alpha) => switch (genre) {
    GenreLoi.binomiale => 'binomial_icdf(${_p(0)},${_p(1)},$alpha)',
    GenreLoi.poisson => 'poisson_icdf(${_p(0)},$alpha)',
    GenreLoi.geometrique => 'geometric_icdf(${_p(0)},$alpha)',
    GenreLoi.normale => 'normald_icdf(${_p(0)},sqrt(${_p(1)}),$alpha)',
    GenreLoi.exponentielle => '-ln(1-($alpha))/${_p(0)}',
    GenreLoi.uniforme => '${_p(0)}+($alpha)*(${_p(1)}-${_p(0)})',
  };
}

/// Le nom écrit d'une loi, sans police (`\mathcal{B}`, `\mathscr{N}`) :
/// `B`, `Bin`, `binomiale`…
GenreLoi? _genre(String nom) => switch (nom.toLowerCase()) {
  'b' || 'bin' || 'binomiale' || 'binomial' => GenreLoi.binomiale,
  'n' || 'normale' || 'normal' => GenreLoi.normale,
  'p' || 'poisson' => GenreLoi.poisson,
  'g' || 'geom' || 'geometrique' || 'geometric' => GenreLoi.geometrique,
  'e' || 'exp' || 'exponentielle' || 'exponential' => GenreLoi.exponentielle,
  'u' || 'uniforme' || 'uniform' => GenreLoi.uniforme,
  _ => null,
};

int _nombreDeParametres(GenreLoi g) => switch (g) {
  GenreLoi.binomiale || GenreLoi.normale || GenreLoi.uniforme => 2,
  _ => 1,
};

/// Sans polices ni `\left`/`\right`, `\,` et espaces : de quoi lire la ligne.
String _nu(String latex) => sansLeftRight(latex)
    .replaceAll(RegExp(r'\\(?:sim|thicksim|backsim)(?![a-z])'), '~')
    .replaceAllMapped(
      RegExp(
        r'\\(?:mathcal|mathscr|mathbb|mathrm|mathit|mathbf|operatorname|text|textrm|textit)\s*\{\s*([^{}]*?)\s*\}',
      ),
      (m) => m[1]!,
    )
    .replaceAll(RegExp(r'\\[,;:!]|\\quad'), '')
    .replaceAll(RegExp(r'\\(?:leqslant|leq|le)(?![a-zA-Z])'), '≤')
    .replaceAll(RegExp(r'\\(?:geqslant|geq|ge)(?![a-zA-Z])'), '≥')
    .replaceAll('⩽', '≤')
    .replaceAll('⩾', '≥')
    .replaceAll(RegExp(r'\\(?:lt)(?![a-zA-Z])'), '<')
    .replaceAll(RegExp(r'\\(?:gt)(?![a-zA-Z])'), '>')
    .replaceAll(RegExp(r'\\(?:sim|thicksim|backsim)(?![a-zA-Z])'), '~')
    .replaceAll('∼', '~')
    .replaceAll(RegExp(r'\s+'), '')
    .trim();

/// Coupe [texte] à chaque [signe] hors des parenthèses et accolades.
List<String> _couper(String texte, String signe) {
  final morceaux = <String>[];
  var profondeur = 0;
  var debut = 0;
  for (var i = 0; i < texte.length; i++) {
    final c = texte[i];
    if ('({['.contains(c)) profondeur++;
    if (')}]'.contains(c)) profondeur--;
    if (c == signe && profondeur == 0) {
      morceaux.add(texte.substring(debut, i));
      debut = i + 1;
    }
  }
  morceaux.add(texte.substring(debut));
  return morceaux;
}

/// `X \sim B(10;0{,}3)` : la déclaration d'une loi, ou `null`.
Analyse? analyserLoi(String latex, {Map<String, String> valeurs = const {}}) {
  final ligne = _nu(latex);
  final m = RegExp(r'^([A-Z])~([A-Za-z]+)\((.*)\)$').firstMatch(ligne);
  if (m == null) return null;
  final genre = _genre(m[2]!);
  if (genre == null) throw ErreurLatex('loi inconnue : ${m[2]}');
  final attendus = _nombreDeParametres(genre);
  var morceaux = _couper(m[3]!, ';');
  if (morceaux.length != attendus) morceaux = _couper(m[3]!, ',');
  if (morceaux.length != attendus) {
    throw ErreurLatex('${genre.name} : $attendus paramètre(s) attendu(s)');
  }
  final parametres = [
    for (final p in morceaux) analyserLatex(p, valeurs: valeurs).giac,
  ];
  return Analyse(
    TypeExpression.calcul,
    Loi(genre, parametres).valeur,
    nomValeur: m[1],
  );
}

/// Les signes d'ordre lus dans une probabilité.
const _ordres = ['≤', '≥', '<', '>', '='];

/// `P(X\le 3)=`, `E(X)=`, `P(X\le t)=0{,}95` : un calcul sur une variable
/// aléatoire déclarée plus haut, ou `null`.
Analyse? analyserProbabilite(
  String latex, {
  Map<String, String> valeurs = const {},
}) {
  final ligne = _nu(latex);
  // E(X), V(X), σ(X) : espérance, variance, écart type.
  // Une minuscule vaut la majuscule déclarée : le modèle lit souvent `x`
  // pour un `X` écrit à la main, mais jamais si x vaut déjà autre chose.
  String? declaree(String lettre) {
    if (Loi.lire(valeurs[lettre]) != null) return lettre;
    final grande = lettre.toUpperCase();
    if (grande != lettre &&
        !valeurs.containsKey(lettre) &&
        Loi.lire(valeurs[grande]) != null) {
      return grande;
    }
    return null;
  }

  final moment = RegExp(r'^(E|V|\\sigma|σ)\(([A-Za-z])\)=?$').firstMatch(ligne);
  if (moment != null) {
    final variable = declaree(moment[2]!);
    final loi = variable == null ? null : Loi.lire(valeurs[variable]);
    if (loi == null) return null;
    final giac = switch (moment[1]) {
      'E' => loi.esperance,
      'V' => loi.variance,
      _ => 'sqrt(${loi.variance})',
    };
    return Analyse(TypeExpression.calcul, giac, demandeResultat: true);
  }
  final p = RegExp(r'^[Pp]\((.*)\)(?:(=)|(≤|≥|=|<|>)(.+))?$').firstMatch(ligne);
  if (p == null) return null;
  var dedans = p[1]!;
  // `p(x)=x^2` reste une fonction : une probabilité porte un signe d'ordre.
  if (!_ordres.any(dedans.contains)) return null;
  // La variable : la seule lettre déclarée comme loi. Sa minuscule ne
  // compte que si aucune variable déclarée n'est écrite telle quelle :
  // dans `P(Y≤t)=0,975`, t est le seuil, même si T est une loi (banc).
  final toutes = RegExp('[A-Za-z]')
      .allMatches(dedans)
      .map((m) => m[0]!)
      .toSet();
  final exactes = toutes.where((n) => Loi.lire(valeurs[n]) != null).toSet();
  final lettres = exactes.isNotEmpty
      ? exactes
      : toutes.where((n) => declaree(n) != null).toSet();
  if ({for (final l in lettres) declaree(l)}.length != 1) return null;
  final nom = declaree(lettres.first)!;
  for (final l in lettres) {
    dedans = dedans.replaceAll(l, nom);
  }
  final loi = Loi.lire(valeurs[nom])!;
  // Les morceaux et les signes, dans l'ordre : `2`, `≤`, `X`, `<`, `5`.
  final morceaux = <String>[];
  final signes = <String>[];
  var courant = StringBuffer();
  for (var i = 0; i < dedans.length; i++) {
    final c = dedans[i];
    if (_ordres.contains(c)) {
      morceaux.add(courant.toString());
      signes.add(c);
      courant = StringBuffer();
    } else {
      courant.write(c);
    }
  }
  morceaux.add(courant.toString());
  final ou = morceaux.indexOf(nom);
  if (ou < 0 || signes.isEmpty || signes.length > 2) {
    throw ErreurLatex('probabilité non comprise : P($dedans)');
  }
  // Ramené à « bas ≤/< X ≤/< haut ».
  String? bas;
  String? haut;
  var basStrict = false;
  var hautStrict = false;
  void bornes(String signe, String autre, {required bool avant}) {
    // avant : `autre signe X` ; sinon `X signe autre`.
    final s = avant
        ? signe
        : switch (signe) {
            '≤' => '≥',
            '≥' => '≤',
            '<' => '>',
            '>' => '<',
            _ => '=',
          };
    switch (s) {
      case '≤' || '<':
        bas = autre;
        basStrict = s == '<';
      case '≥' || '>':
        haut = autre;
        hautStrict = s == '>';
      default:
        bas = autre;
        haut = autre;
    }
  }

  if (ou == 0 && signes.length == 1) {
    bornes(signes[0], morceaux[1], avant: false);
  } else if (ou == 1 && signes.length == 1) {
    bornes(signes[0], morceaux[0], avant: true);
  } else if (ou == 1 && signes.length == 2) {
    bornes(signes[0], morceaux[0], avant: true);
    bornes(signes[1], morceaux[2], avant: false);
  } else {
    throw ErreurLatex('probabilité non comprise : P($dedans)');
  }

  // Un seuil : `P(X ≤ t) = 0,95`, `P(X ≤ k) ≥ 0,95`.
  final ordreSeuil = p[3];
  if (ordreSeuil != null) {
    final inconnue = haut ?? bas;
    if (inconnue == null || !RegExp(r'^[a-z]$').hasMatch(inconnue)) {
      throw const ErreurLatex('seuil : une lettre attendue dans P(…)');
    }
    final alpha = analyserLatex(p[4]!, valeurs: valeurs).giac;
    final versLeHaut = haut == inconnue; // P(X ≤ t)
    if (loi.discrete) {
      // Le plus petit entier k tel que P(X ≤ k) ≥ α.
      if (!versLeHaut ||
          hautStrict ||
          !(ordreSeuil == '≥' || ordreSeuil == '>')) {
        throw const ErreurLatex('seuil discret : écrire P(X≤k)≥α');
      }
      return Analyse(
        TypeExpression.equation,
        'solve($inconnue>=${loi.quantile(alpha)},$inconnue)',
        inconnues: [inconnue],
      );
    }
    if (ordreSeuil != '=') {
      throw const ErreurLatex('seuil continu : écrire P(X≤t)=α');
    }
    final niveau = versLeHaut ? alpha : '1-($alpha)';
    return Analyse(
      TypeExpression.equation,
      'solve($inconnue=evalf(${loi.quantile(niveau)}),$inconnue)',
      inconnues: [inconnue],
    );
  }

  if (loi.discrete) {
    int? entier(
      String? texte, {
      required bool versLeBas,
      required bool strict,
    }) {
      if (texte == null) return null;
      final v = _nombre(texte);
      if (v == null) {
        throw ErreurLatex('borne non numérique : $texte');
      }
      if (versLeBas) {
        // X ≥ v (ou > v) : premier entier au-dessus.
        final e = v.ceilToDouble();
        return (strict && e == v ? e + 1 : e).toInt();
      }
      final e = v.floorToDouble();
      return (strict && e == v ? e - 1 : e).toInt();
    }

    final giac = loi.probabiliteEntre(
      entier(bas, versLeBas: true, strict: basStrict),
      entier(haut, versLeBas: false, strict: hautStrict),
    );
    return Analyse(TypeExpression.calcul, giac, demandeResultat: true);
  }
  final b = bas;
  final h = haut;
  if (b != null && b == h) {
    // P(X = a) d'une loi continue : 0.
    return const Analyse(TypeExpression.calcul, '0', demandeResultat: true);
  }
  // ±∞ écrit comme borne : pas de borne.
  String? giac(String? t) => t == null || t.contains(r'\infty')
      ? null
      : analyserLatex(t, valeurs: valeurs).giac;
  return Analyse(
    TypeExpression.calcul,
    loi.probabiliteContinue(giac(b), giac(h)),
    demandeResultat: true,
  );
}

/// Un nombre écrit : `3`, `-2`, `1{,}5`, `2.5`, `\frac{7}{2}`.
double? _nombre(String texte) {
  final t = texte.replaceAll('{,}', '.').replaceAll(',', '.');
  final simple = double.tryParse(t);
  if (simple != null) return simple;
  final f = RegExp(r'^(-?)\\frac\{(-?\d+)\}\{(\d+)\}$').firstMatch(t);
  if (f != null) {
    final v = int.parse(f[2]!) / int.parse(f[3]!);
    return f[1] == '-' ? -v : v;
  }
  return null;
}
