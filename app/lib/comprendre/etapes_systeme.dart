import 'package:fikajiana/comprendre/etapes.dart';
import 'package:fikajiana/moteur/giac.dart';
import 'package:fikajiana/moteur/moteur.dart';

/// `solve([e1,e2],[x,y])` lu en ses deux équations (membres pour Giac) et
/// ses deux inconnues ; `null` pour un autre système (trois équations,
/// inégalités).
({List<(String, String)> equations, String x, String y})? lireSysteme(
  String giac,
) {
  final m = RegExp(r'^solve\(\[(.*)\],\[([a-zA-Z]),([a-zA-Z])\]\)$')
      .firstMatch(giac);
  if (m == null) return null;
  final morceaux = _separer(m[1]!);
  if (morceaux.length != 2) return null;
  final equations = <(String, String)>[];
  for (final e in morceaux) {
    if (RegExp('[<>]').hasMatch(e) || '='.allMatches(e).length != 1) {
      return null;
    }
    final [gauche, droite] = e.split('=');
    if (gauche.trim().isEmpty || droite.trim().isEmpty) return null;
    equations.add((gauche.trim(), droite.trim()));
  }
  return (equations: equations, x: m[2]!, y: m[3]!);
}

/// Coupe sur les virgules hors de toute parenthèse ou crochet.
List<String> _separer(String texte) {
  final morceaux = <String>[];
  var profondeur = 0;
  var debut = 0;
  for (var i = 0; i < texte.length; i++) {
    final c = texte[i];
    if ('([{'.contains(c)) profondeur++;
    if (')]}'.contains(c)) profondeur--;
    if (c == ',' && profondeur == 0) {
      morceaux.add(texte.substring(debut, i));
      debut = i + 1;
    }
  }
  morceaux.add(texte.substring(debut));
  return morceaux;
}

/// Une équation `a·x + b·y = c` du système, ses coefficients lus par Giac.
class _Ligne {
  const new(this.a, this.b, this.c);

  final ReponseGiac a;
  final ReponseGiac b;
  final ReponseGiac c;

  ReponseGiac coef(int k) => k == 0 ? a : b;
}

/// Les étapes de la résolution d'un système linéaire de deux équations à
/// deux inconnues, comme au tableau (programme de seconde,
/// https://eduscol.education.gouv.fr/document/24553/download) :
/// une équation à une seule inconnue se résout d'abord ; sinon, par
/// substitution si une inconnue a pour coefficient 1 ou −1, par
/// combinaison des lignes E₁ et E₂ sinon ; puis on remonte à l'autre
/// inconnue. Giac fait chaque calcul.
///
/// `null` si le système n'est pas linéaire à coefficients numériques, ou
/// s'il n'a pas une solution unique (déterminant nul).
Future<List<Etape>?> etapesSysteme(
  Moteur moteur, {
  required String ecrit,
  required List<(String, String)> equations,
  required String x,
  required String y,
}) async {
  Future<ReponseGiac?> g(String e) => giacAuTableau(moteur, e);
  bool nul(ReponseGiac r) => double.tryParse(r.approche) == 0;
  final inconnues = [x, y];

  final lignes = <_Ligne>[];
  for (final (gauche, droite) in equations) {
    final p = 'expand(($gauche)-($droite))';
    final degreX = await g('degree($p,$x)');
    final degreY = await g('degree($p,$y)');
    final croise = await g('coeff(coeff($p,$x,1),$y,1)');
    final a = await g('coeff($p,$x,1)');
    final b = await g('coeff($p,$y,1)');
    final c = await g('-subst($p,[$x,$y],[0,0])');
    if (degreX == null ||
        degreY == null ||
        croise == null ||
        a == null ||
        b == null ||
        c == null) {
      return null;
    }
    if (int.parse(degreX.exact) > 1 ||
        int.parse(degreY.exact) > 1 ||
        !nul(croise) ||
        [a, b, c].any((r) => double.tryParse(r.approche) == null)) {
      return null;
    }
    lignes.add(_Ligne(a, b, c));
  }
  final [l1, l2] = lignes;
  final det = await g(
    '(${l1.a.exact})*(${l2.b.exact})-(${l2.a.exact})*(${l1.b.exact})',
  );
  if (det == null || nul(det)) return null;

  final etapes = <Etape>[Etape(RaisonEtape.departSysteme, ecrit)];
  // L'équation écrite `a·x + b·y = c`, réduite.
  String equation(_Ligne l) =>
      '${_lineaire([(l.a, x), (l.b, y)])}=${l.c.latex}';
  final reduit = '\\begin{cases}${equation(l1)}\\\\${equation(l2)}\\end{cases}';
  // Déjà écrit a·x + b·y = c : la ligne serait la même.
  if (reduit.replaceAll(' ', '') != ecrit.replaceAll(' ', '')) {
    etapes.add(Etape(RaisonEtape.reduireSysteme, reduit));
  }

  // On cherche d'abord une inconnue (`connue`), puis l'autre.
  late final int connue;
  late final ReponseGiac valeur;
  late final int ligneRestante;

  // 1. Une équation n'a qu'une inconnue : on la résout tout de suite.
  int? seule;
  for (var i = 0; i < 2 && seule == null; i++) {
    for (var k = 0; k < 2; k++) {
      if (nul(lignes[i].coef(1 - k))) {
        seule = i;
        connue = k;
      }
    }
  }
  if (seule != null) {
    final l = lignes[seule];
    final v = await g('normal((${l.c.exact})/(${l.coef(connue).exact}))');
    if (v == null) return null;
    valeur = v;
    ligneRestante = 1 - seule;
    etapes.add(
      Etape(
        RaisonEtape.uneSeuleInconnue,
        '${_nomLigne(seule)}:\\ ${inconnues[connue]}=${v.latex}',
      ),
    );
  } else {
    // 2. Un coefficient 1 ou −1 : substitution.
    (int, int)? isolable;
    for (var i = 0; i < 2 && isolable == null; i++) {
      for (var k = 0; k < 2 && isolable == null; k++) {
        final e = lignes[i].coef(k).exact.trim();
        if (e == '1' || e == '-1') isolable = (i, k);
      }
    }
    if (isolable != null) {
      final (i, k) = isolable;
      final l = lignes[i];
      final autre = lignes[1 - i];
      final v = inconnues[k];
      final w = inconnues[1 - k];
      final expression = await g(
        'expand(((${l.c.exact})-(${l.coef(1 - k).exact})*$w)/'
        '(${l.coef(k).exact}))',
      );
      if (expression == null) return null;
      final reduite = await g(
        'expand((${autre.coef(k).exact})*(${expression.exact})+'
        '(${autre.coef(1 - k).exact})*$w)',
      );
      final w0 = await g(
        'normal(solve((${autre.coef(k).exact})*(${expression.exact})+'
        '(${autre.coef(1 - k).exact})*$w=${autre.c.exact},$w)[0])',
      );
      if (reduite == null || w0 == null) return null;
      // L'autre ligne, v remplacé par son expression, dans l'ordre x puis y.
      final remplacee = [
        for (var n = 0; n < 2; n++)
          if (n == k)
            (autre.coef(k), '\\left(${expression.latex}\\right)')
          else
            (autre.coef(1 - k), w),
      ];
      etapes
        ..add(
          Etape(
            RaisonEtape.isolerSysteme,
            '${_nomLigne(i)}:\\ $v=${expression.latex}',
          ),
        )
        ..add(
          Etape(
            RaisonEtape.substituer,
            '${_nomLigne(1 - i)}:\\ ${_lineaire(remplacee)}=${autre.c.latex}',
          ),
        )
        ..add(
          Etape(RaisonEtape.reduireUne, '${reduite.latex}=${autre.c.latex}'),
        )
        ..add(Etape(RaisonEtape.resoudreUne, '$w=${w0.latex}'));
      // On remonte dans l'expression de v.
      final v0 = await g('normal(subst(${expression.exact},$w=${w0.exact}))');
      if (v0 == null) return null;
      etapes
        ..add(
          Etape(
            RaisonEtape.remonter,
            '$v=${_remplacer(expression.latex, w, w0.latex)}=${v0.latex}',
          ),
        )
        ..add(
          Etape(
            RaisonEtape.conclusion,
            _ensemble(k == 0 ? v0 : w0, k == 0 ? w0 : v0),
          ),
        );
      return etapes;
    }

    // 3. Combinaison : on élimine x entre E₁ et E₂.
    final entiers = [
      l1.a,
      l2.a,
    ].every((r) => RegExp(r'^-?\d+$').hasMatch(r.exact.trim()));
    final d = entiers
        ? await g('gcd(${l1.a.exact},${l2.a.exact})')
        : await g('1');
    if (d == null) return null;
    final k1 = await g('(${l2.a.exact})/(${d.exact})');
    final k2 = await g('(${l1.a.exact})/(${d.exact})');
    if (k1 == null || k2 == null) return null;
    final coefY = await g(
      '(${k1.exact})*(${l1.b.exact})-(${k2.exact})*(${l2.b.exact})',
    );
    final second = await g(
      '(${k1.exact})*(${l1.c.exact})-(${k2.exact})*(${l2.c.exact})',
    );
    final y0 = await g('normal((${second?.exact})/(${coefY?.exact}))');
    if (coefY == null || second == null || y0 == null) return null;
    final moinsK2 = await g('-(${k2.exact})');
    if (moinsK2 == null) return null;
    etapes
      ..add(
        Etape(
          RaisonEtape.combiner,
          '${_lineaire([(k1, 'E_{1}'), (moinsK2, 'E_{2}')])}:\\ '
          '${_lineaire([(coefY, y)])}=${second.latex}',
        ),
      )
      ..add(Etape(RaisonEtape.resoudreUne, '$y=${y0.latex}'));
    connue = 1;
    valeur = y0;
    ligneRestante = 0;
  }

  // On remonte : la valeur trouvée dans l'autre équation.
  final l = lignes[ligneRestante];
  final k = 1 - connue;
  final autre = await g(
    'normal(((${l.c.exact})-(${l.coef(connue).exact})*(${valeur.exact}))/'
    '(${l.coef(k).exact}))',
  );
  if (autre == null) return null;
  final avecValeur = [
    for (var n = 0; n < 2; n++)
      if (n == connue)
        (l.coef(connue), '\\left(${valeur.latex}\\right)')
      else
        (l.coef(k), inconnues[k]),
  ];
  etapes
    ..add(
      Etape(
        RaisonEtape.remonter,
        '${_nomLigne(ligneRestante)}:\\ ${_lineaire(avecValeur)}=${l.c.latex}',
      ),
    )
    ..add(Etape(RaisonEtape.resoudreUne, '${inconnues[k]}=${autre.latex}'))
    ..add(
      Etape(
        RaisonEtape.conclusion,
        _ensemble(k == 0 ? autre : valeur, k == 0 ? valeur : autre),
      ),
    );
  return etapes;
}

String _nomLigne(int i) => 'E_{${i + 1}}';

/// `S = {(x₀ ; y₀)}`.
String _ensemble(ReponseGiac x0, ReponseGiac y0) =>
    'S=\\left\\{\\left(${x0.latex};${y0.latex}\\right)\\right\\}';

/// `2x - y`, `E_{1}-2E_{2}` : chaque coefficient devant son objet, sans
/// `1·`, sans `+-`, sans terme nul.
String _lineaire(List<(ReponseGiac, String)> termes) {
  final morceaux = <String>[];
  for (final (k, objet) in termes) {
    final e = k.exact.trim();
    if (double.tryParse(k.approche) == 0) continue;
    final coef = e == '1'
        ? ''
        : e == '-1'
        ? '-'
        : RegExp(r'^-?[\d.]+$|^-?\\frac').hasMatch(k.latex)
        ? k.latex
        : '\\left(${k.latex}\\right)';
    // Un nombre devant une parenthèse ou un autre nombre : le point.
    final point =
        coef.isNotEmpty &&
        coef != '-' &&
        RegExp(r'^(\\left|\d)').hasMatch(objet);
    const fois = r'\cdot ';
    morceaux.add('$coef${point ? fois : ''}$objet');
  }
  if (morceaux.isEmpty) return '0';
  return morceaux.join('+').replaceAll('+-', '-');
}

/// [latex] où l'inconnue [w] prend la valeur [valeur], écrite entre
/// parenthèses : `5-2x` devient `5-2\cdot \left(2\right)`.
String _remplacer(String latex, String w, String valeur) =>
    latex.replaceAllMapped(
      RegExp('(?<![a-zA-Z\\\\])(\\d|\\})?$w(?![a-zA-Z])'),
      (m) => '${m[1] == null ? '' : '${m[1]}\\cdot '}\\left($valeur\\right)',
    );
