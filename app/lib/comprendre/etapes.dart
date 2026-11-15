import 'package:fikajiana/moteur/giac.dart';
import 'package:fikajiana/moteur/moteur.dart';

/// Pourquoi une ligne suit la précédente : la phrase dite à côté d'elle.
enum RaisonEtape {
  /// L'équation telle qu'elle est écrite.
  depart,

  /// Tout dans le membre de gauche, développé et réduit.
  toutAGauche,

  /// Les termes sans l'inconnue passent à droite.
  isoler,

  /// On divise par le coefficient de l'inconnue.
  diviser,

  /// On lit a, b et c.
  coefficients,

  /// Δ = b² − 4ac.
  discriminant,

  /// Δ > 0 : deux solutions.
  deuxSolutions,

  /// Δ = 0 : une solution double.
  solutionDouble,

  /// Δ < 0 : pas de solution réelle.
  aucuneSolution,

  /// La première, puis la seconde solution.
  premiere,
  seconde,

  /// L'ensemble des solutions.
  conclusion,

  /// L'inéquation telle qu'elle est écrite.
  departInequation,

  /// Inéquation : on divise par un nombre négatif, le sens change.
  diviserNegatif,

  /// Inéquation du second degré : les racines du trinôme.
  racines,

  /// Le trinôme a une racine double.
  racineDouble,

  /// Δ < 0 : le trinôme ne s'annule pas.
  pasDeRacine,

  /// Le trinôme a le signe de a hors des racines, l'autre entre elles.
  signeTrinome,

  /// Dérivée : la fonction à dériver.
  deriveeDepart,

  /// Une formule du cours appliquée directement (xⁿ, sin x, eˣ…).
  usuelle,

  /// La dérivée d'une somme est la somme des dérivées.
  somme,

  /// Un nombre fois u : (ku)' = ku'.
  nombreFois,

  /// On nomme les morceaux : u, et v.
  poser,

  /// On dérive les morceaux.
  deriverMorceaux,

  /// La formule du cours utilisée (produit, quotient, composée…).
  formule,

  /// On remplace dans la formule.
  remplacer,

  /// Système : tel qu'il est écrit.
  departSysteme,

  /// Chaque ligne écrite a·x + b·y = c.
  reduireSysteme,

  /// Une ligne n'a qu'une inconnue : on la résout d'abord.
  uneSeuleInconnue,

  /// On isole l'inconnue de coefficient 1 ou −1.
  isolerSysteme,

  /// On la remplace dans l'autre ligne.
  substituer,

  /// Il ne reste qu'une inconnue : on développe et on réduit.
  reduireUne,

  /// On résout l'équation à une inconnue.
  resoudreUne,

  /// On multiplie et on soustrait les lignes : une inconnue disparaît.
  combiner,

  /// On remplace la valeur trouvée pour avoir l'autre inconnue.
  remonter,
}

/// Une ligne de la résolution, et sa raison.
class Etape {
  const new(this.raison, this.latex);

  final RaisonEtape raison;
  final String latex;

  @override
  String toString() => '${raison.name} : $latex';
}

/// Le calcul de Giac écrit comme au tableau : `-5` et `2x`, pas
/// `\mathrm{-5}` ni `2\cdot x`. `null` si Giac échoue.
Future<ReponseGiac?> giacAuTableau(Moteur moteur, String entree) =>
    _giac(moteur, entree);

Future<ReponseGiac?> _giac(Moteur moteur, String entree) async {
  final r = await moteur.calculer(entree);
  if (r.arrete || r.erreur != null || r.exact.trim().isEmpty) return null;
  final latex = r.latex
      .replaceAllMapped(RegExp(r'\\mathrm\{(-[0-9.,]+)\}'), (m) => m[1]!)
      .replaceAllMapped(
        RegExp(r'(\d|\}) ?\\cdot ([a-zA-Z])'),
        (m) => '${m[1]}${m[2]}',
      )
      // `2\cdot \sin`, `x^{2}\cdot e^{x}` : `2\sin`, `x^{2}e^{x}`.
      .replaceAllMapped(
        RegExp(r'([\da-zA-Z}]) ?\\cdot (\\(?:sin|cos|tan|ln|sqrt|left)|e\^)'),
        (m) => '${m[1]}${m[1]!.contains(RegExp('[a-zA-Z]')) ? ' ' : ''}${m[2]}',
      );
  return ReponseGiac(
    exact: r.exact,
    latex: _sansParenthesesSeules(latex),
    approche: r.approche,
  );
}

/// `\frac{(x+1)}{(x-1)}` : `\frac{x+1}{x-1}`. Les parenthèses qui occupent
/// tout un groupe `{…}` ne servent à rien.
String _sansParenthesesSeules(String latex) {
  final s = StringBuffer();
  var i = 0;
  while (i < latex.length) {
    if (latex.startsWith('{(', i)) {
      var profondeur = 0;
      var fin = -1;
      for (var j = i + 1; j < latex.length; j++) {
        if (latex[j] == '(') profondeur++;
        if (latex[j] == ')') profondeur--;
        if (profondeur == 0) {
          fin = j;
          break;
        }
      }
      if (fin > 0 && fin + 1 < latex.length && latex[fin + 1] == '}') {
        s.write('{${_sansParenthesesSeules(latex.substring(i + 2, fin))}}');
        i = fin + 2;
        continue;
      }
    }
    s.write(latex[i]);
    i++;
  }
  return s.toString();
}

/// Le degré de `p` en [x] (1 ou 2) et ses coefficients numériques, du plus
/// haut degré à la constante ; `null` sinon.
Future<List<ReponseGiac>?> _coefficients(
  Moteur moteur,
  String p,
  String x,
) async {
  final degre = await _giac(moteur, 'degree(expand($p),$x)');
  final n = int.tryParse(degre?.exact.trim() ?? '');
  if (n != 1 && n != 2) return null;
  final coefficients = <ReponseGiac>[];
  for (var k = n!; k >= 0; k--) {
    final c = await _giac(moteur, 'coeff(expand($p),$x,$k)');
    if (c == null || double.tryParse(c.approche) == null) return null;
    coefficients.add(c);
  }
  return coefficients;
}

/// Entre parenthèses dès qu'un signe ou une opération s'y trouve.
String _entre(ReponseGiac c) => RegExp(r'^[0-9.,]+$').hasMatch(c.latex)
    ? c.latex
    : '\\left(${c.latex}\\right)';

/// Les étapes de la résolution de `gauche = droite` en [x], comme un
/// professeur les écrit au tableau : degré 1, ou degré 2 par le discriminant
/// (programme de première, https://eduscol.education.gouv.fr/document/24553/download).
///
/// Giac fait chaque calcul ; rien n'est simplifié à la main. Rend `null` si
/// l'équation n'est pas un polynôme de degré 1 ou 2 à coefficients
/// numériques : pas d'étapes plutôt que des étapes fausses.
Future<List<Etape>?> etapesEquation(
  Moteur moteur, {
  required String ecrit,
  required String gauche,
  required String droite,
  required String x,
  String ou = 'ou',
}) async {
  Future<ReponseGiac?> giac(String entree) => _giac(moteur, entree);

  final p = '(($gauche)-($droite))';
  final coefficients = await _coefficients(moteur, p, x);
  if (coefficients == null) return null;
  final n = coefficients.length - 1;
  final reduit = await giac('expand($p)');
  if (reduit == null) return null;
  final etapes = <Etape>[Etape(RaisonEtape.depart, ecrit)];
  // Déjà « = 0 » sans rien à développer : la ligne serait la même.
  final dejaReduit =
      droite.trim() == '0' && !RegExp(r'[()]|\\frac').hasMatch(ecrit);
  if (!dejaReduit) {
    etapes.add(Etape(RaisonEtape.toutAGauche, '${reduit.latex}=0'));
  }

  if (n == 1) {
    final [a, b] = coefficients;
    final ax = await giac('(${a.exact})*$x');
    final moinsB = await giac('-(${b.exact})');
    final solution = await giac('-(${b.exact})/(${a.exact})');
    if (ax == null || moinsB == null || solution == null) return null;
    if (double.parse(b.approche) != 0) {
      etapes.add(Etape(RaisonEtape.isoler, '${ax.latex}=${moinsB.latex}'));
    }
    if (double.parse(a.approche) != 1) {
      etapes.add(
        Etape(RaisonEtape.diviser, '$x=\\frac{${moinsB.latex}}{${a.latex}}'),
      );
    }
    etapes.add(Etape(RaisonEtape.conclusion, '$x=${solution.latex}'));
    return etapes;
  }

  final [a, b, c] = coefficients;
  etapes.add(
    Etape(
      RaisonEtape.coefficients,
      'a=${a.latex},\\ b=${b.latex},\\ c=${c.latex}',
    ),
  );
  final delta = await giac('(${b.exact})^2-4*(${a.exact})*(${c.exact})');
  final signe = double.tryParse(delta?.approche ?? '');
  if (delta == null || signe == null) return null;
  etapes.add(
    Etape(
      RaisonEtape.discriminant,
      '\\Delta=b^{2}-4ac=${_entre(b)}^{2}-4\\times ${_entre(a)}\\times '
      '${_entre(c)}=${delta.latex}',
    ),
  );
  if (signe < 0) {
    etapes.add(const Etape(RaisonEtape.aucuneSolution, r'\Delta<0'));
    return etapes;
  }
  if (signe == 0) {
    final x0 = await giac('-(${b.exact})/(2*(${a.exact}))');
    if (x0 == null) return null;
    etapes
      ..add(
        Etape(
          RaisonEtape.solutionDouble,
          '${x}_{0}=\\frac{-b}{2a}=${x0.latex}',
        ),
      )
      ..add(Etape(RaisonEtape.conclusion, '$x=${x0.latex}'));
    return etapes;
  }
  final x1 = await giac(
    'simplify((-(${b.exact})-sqrt(${delta.exact}))/(2*(${a.exact})))',
  );
  final x2 = await giac(
    'simplify((-(${b.exact})+sqrt(${delta.exact}))/(2*(${a.exact})))',
  );
  if (x1 == null || x2 == null) return null;
  etapes
    ..add(const Etape(RaisonEtape.deuxSolutions, r'\Delta>0'))
    ..add(
      Etape(
        RaisonEtape.premiere,
        '${x}_{1}=\\frac{-b-\\sqrt{\\Delta}}{2a}=${x1.latex}',
      ),
    )
    ..add(
      Etape(
        RaisonEtape.seconde,
        '${x}_{2}=\\frac{-b+\\sqrt{\\Delta}}{2a}=${x2.latex}',
      ),
    )
    ..add(
      Etape(
        RaisonEtape.conclusion,
        '$x=${x1.latex}\\ \\text{$ou}\\ $x=${x2.latex}',
      ),
    );
  return etapes;
}

/// Le sens d'une inéquation : `<`, `>`, `≤` ou `≥`.
enum Sens {
  inferieur('<', '<'),
  superieur('>', '>'),
  inferieurOuEgal('<=', r'\leq '),
  superieurOuEgal('>=', r'\geq ');

  new(this.giac, this.latex);

  /// Tel que Giac l'écrit.
  final String giac;

  /// Tel qu'on l'écrit.
  final String latex;

  /// Le sens que lit Giac (`<=`…), ou `null`.
  static Sens? lire(String giac) =>
      values.where((s) => s.giac == giac).firstOrNull;

  bool get strict => this == inferieur || this == superieur;

  /// On cherche où le membre de gauche est positif (`>`, `≥`).
  bool get positif => this == superieur || this == superieurOuEgal;

  /// Le sens après une division par un nombre négatif.
  Sens get contraire => switch (this) {
    inferieur => superieur,
    superieur => inferieur,
    inferieurOuEgal => superieurOuEgal,
    superieurOuEgal => inferieurOuEgal,
  };
}

/// `solve(G<D,x)` lu en ses membres et son sens ; `null` s'il n'y a pas un
/// seul signe `<`, `>`, `<=` ou `>=`, sans autre `=` (`1<x<3`).
({String gauche, Sens sens, String droite, String x})? lireInequation(
  String giac,
  String x,
) {
  final corps = RegExp('^solve\\((.*),${RegExp.escape(x)}\\)\$')
      .firstMatch(giac)?[1];
  if (corps == null) return null;
  final signes = RegExp('<=|>=|<|>').allMatches(corps).toList();
  if (signes.length != 1) return null;
  final m = signes.single;
  if ('='.allMatches(corps).length != m[0]!.length - 1) return null;
  final sens = Sens.lire(m[0]!);
  final gauche = corps.substring(0, m.start).trim();
  final droite = corps.substring(m.end).trim();
  if (sens == null || gauche.isEmpty || droite.isEmpty) return null;
  return (gauche: gauche, sens: sens, droite: droite, x: x);
}

/// `]-∞ ; v[`, `[v ; +∞[`… : la notation française des intervalles
/// (https://eduscol.education.gouv.fr/document/24553/download).
String _intervalle(
  String? debut,
  bool debutCompris,
  String? fin,
  bool finCompris,
) {
  final gauche = debut == null
      ? r'\left]-\infty'
      : debutCompris
      ? '\\left[$debut'
      : '\\left]$debut';
  final droite = fin == null
      ? r'+\infty\right['
      : finCompris
      ? '$fin\\right]'
      : '$fin\\right[';
  return '$gauche;$droite';
}

/// Les étapes de la résolution de `gauche [sens] 0` en [x], comme au
/// tableau : degré 1 en isolant l'inconnue (le sens change si l'on divise
/// par un négatif), degré 2 par le signe du trinôme, du signe de a hors des
/// racines (programme de première,
/// https://eduscol.education.gouv.fr/document/24553/download).
///
/// Giac fait chaque calcul. Rend `null` hors du premier et du second degré
/// à coefficients numériques.
Future<List<Etape>?> etapesInequation(
  Moteur moteur, {
  required String ecrit,
  required String gauche,
  required Sens sens,
  required String droite,
  required String x,
}) async {
  Future<ReponseGiac?> giac(String entree) => _giac(moteur, entree);

  final p = '(($gauche)-($droite))';
  final coefficients = await _coefficients(moteur, p, x);
  if (coefficients == null) return null;
  final reduit = await giac('expand($p)');
  if (reduit == null) return null;
  final etapes = <Etape>[Etape(RaisonEtape.departInequation, ecrit)];
  final dejaReduit =
      droite.trim() == '0' && !RegExp(r'[()]|\\frac').hasMatch(ecrit);
  if (!dejaReduit) {
    etapes.add(Etape(RaisonEtape.toutAGauche, '${reduit.latex}${sens.latex}0'));
  }

  if (coefficients.length == 2) {
    final [a, b] = coefficients;
    final ax = await giac('(${a.exact})*$x');
    final moinsB = await giac('-(${b.exact})');
    final solution = await giac('-(${b.exact})/(${a.exact})');
    if (ax == null || moinsB == null || solution == null) return null;
    final va = double.parse(a.approche);
    if (double.parse(b.approche) != 0) {
      etapes.add(
        Etape(RaisonEtape.isoler, '${ax.latex}${sens.latex}${moinsB.latex}'),
      );
    }
    final apres = va < 0 ? sens.contraire : sens;
    if (va != 1) {
      etapes.add(
        Etape(
          va < 0 ? RaisonEtape.diviserNegatif : RaisonEtape.diviser,
          '$x${apres.latex}\\frac{${moinsB.latex}}{${a.latex}}',
        ),
      );
    }
    final v = solution.latex;
    final s = apres.positif
        ? _intervalle(v, !apres.strict, null, false)
        : _intervalle(null, false, v, !apres.strict);
    etapes.add(Etape(RaisonEtape.conclusion, '$x${apres.latex}$v,\\ S=$s'));
    return etapes;
  }

  final [a, b, c] = coefficients;
  etapes.add(
    Etape(
      RaisonEtape.coefficients,
      'a=${a.latex},\\ b=${b.latex},\\ c=${c.latex}',
    ),
  );
  final delta = await giac('(${b.exact})^2-4*(${a.exact})*(${c.exact})');
  final signeDelta = double.tryParse(delta?.approche ?? '');
  if (delta == null || signeDelta == null) return null;
  etapes.add(
    Etape(
      RaisonEtape.discriminant,
      '\\Delta=b^{2}-4ac=${_entre(b)}^{2}-4\\times ${_entre(a)}\\times '
      '${_entre(c)}=${delta.latex}',
    ),
  );
  // Le signe cherché est-il celui de a ?
  final aPositif = double.parse(a.approche) > 0;
  final commeA = sens.positif == aPositif;
  final signeA = aPositif ? '>' : '<';
  const reels = r'\mathbb{R}';
  const vide = r'\emptyset';
  final String s;
  if (signeDelta < 0) {
    etapes.add(
      Etape(RaisonEtape.pasDeRacine, '\\Delta<0,\\ a=${a.latex}${signeA}0'),
    );
    s = commeA ? reels : vide;
  } else if (signeDelta == 0) {
    final x0 = await giac('-(${b.exact})/(2*(${a.exact}))');
    if (x0 == null) return null;
    final v = x0.latex;
    etapes.add(
      Etape(
        RaisonEtape.racineDouble,
        '${x}_{0}=\\frac{-b}{2a}=$v,\\ a=${a.latex}${signeA}0',
      ),
    );
    s = commeA
        ? (sens.strict
              ? '${_intervalle(null, false, v, false)}\\cup '
                    '${_intervalle(v, false, null, false)}'
              : reels)
        : (sens.strict ? vide : '\\left\\{$v\\right\\}');
  } else {
    final r1 = await giac(
      'simplify((-(${b.exact})-sqrt(${delta.exact}))/(2*(${a.exact})))',
    );
    final r2 = await giac(
      'simplify((-(${b.exact})+sqrt(${delta.exact}))/(2*(${a.exact})))',
    );
    final v1 = double.tryParse(r1?.approche ?? '');
    final v2 = double.tryParse(r2?.approche ?? '');
    if (r1 == null || r2 == null || v1 == null || v2 == null) return null;
    etapes.add(
      Etape(
        RaisonEtape.racines,
        '${x}_{1}=\\frac{-b-\\sqrt{\\Delta}}{2a}=${r1.latex},\\ '
        '${x}_{2}=\\frac{-b+\\sqrt{\\Delta}}{2a}=${r2.latex}',
      ),
    );
    // La plus petite racine d'abord (a < 0 les inverse).
    final (petite, grande) = v1 < v2
        ? (r1.latex, r2.latex)
        : (r2.latex, r1.latex);
    etapes.add(Etape(RaisonEtape.signeTrinome, 'a=${a.latex}${signeA}0'));
    final ferme = !sens.strict;
    s = commeA
        ? '${_intervalle(null, false, petite, ferme)}\\cup '
              '${_intervalle(grande, ferme, null, false)}'
        : _intervalle(petite, ferme, grande, ferme);
  }
  etapes.add(Etape(RaisonEtape.conclusion, 'S=$s'));
  return etapes;
}
