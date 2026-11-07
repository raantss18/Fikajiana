import 'dart:math' as math;
import 'dart:ui';

import 'package:fikajiana/comprendre/blocs.dart';
import 'package:fikajiana/comprendre/signes.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/reconnaissance/lecteur.dart';
import 'package:fikajiana_math/fikajiana_math.dart';

/// Ce que le modèle lit mal : ce qui sort d'une seule ligne (ADR 0029). Une
/// matrice, une flèche, de doubles barres se voient sur les traits ; on les
/// découpe, et le modèle ne lit plus que des morceaux simples.
sealed class Structure {
  const new();
}

/// `det (a b ; c d) =` : ce qui précède, les cases, ce qui suit.
class StructureMatrice extends Structure {
  const new(this.tete, this.cases, this.queue, {this.exposant = const []});
  final List<Trait> tete;
  final List<List<List<Trait>>> cases;

  /// Écrit en haut, juste après : `⁻¹` pour l'inverse.
  final List<Trait> exposant;
  final List<Trait> queue;
}

/// `→` au-dessus de `AB`, et ce qui suit.
class StructureFleche extends Structure {
  const new(this.nom, this.queue);
  final List<Trait> nom;
  final List<Trait> queue;
}

/// `A(8;-1)` : le nom, le premier nombre, le second, et ce qui suit.
class StructurePoint extends Structure {
  const new(this.nom, this.premier, this.second, this.queue);
  final List<Trait> nom;
  final List<Trait> premier;
  final List<Trait> second;
  final List<Trait> queue;
}

/// `‖…‖`, et ce qui suit.
class StructureNorme extends Structure {
  const new(this.dedans, this.queue);
  final List<Trait> dedans;
  final List<Trait> queue;
}

Rect _c(Trait t) => cadreDuGroupe([t]);

double _mediane(Iterable<double> v) {
  final l = v.toList()..sort();
  return l.isEmpty ? 0 : l[l.length ~/ 2];
}

/// Un moins, une barre : mesuré sur de vrais moins, jusqu'à la moitié.
bool _plat(Rect c) => c.height <= 0.5 * c.width;

/// La structure qui se voit sur ces traits, ou `null` : une ligne ordinaire.
Structure? trouverStructure(List<Trait> traits) {
  // Une touche involontaire du stylet n'est ni une ligne ni une case.
  final nets = traits.where((t) {
    final c = _c(t);
    return c.width >= 5 || c.height >= 5;
  }).toList();
  if (nets.length < 3) return null;
  return _norme(nets) ?? _fleche(nets) ?? _point(nets) ?? _matrice(nets);
}

/// Un trait sans ventre : une barre. `((` et `))` ne sont pas `‖` (vu sur
/// le Pad 7 : `développer((2x-1)(x-4))` lu comme une norme).
bool _droit(Trait t, double hauteur) {
  final points = [for (final p in t.points) p.position];
  final (a, b) = (points.first, points.last);
  final corde = b - a;
  if (corde.distance == 0) return false;
  final ecart = points
      .map((p) => ((p - a).dx * corde.dy - (p - a).dy * corde.dx).abs())
      .reduce(math.max);
  return ecart / corde.distance <= 0.1 * hauteur;
}

/// Deux barres de chaque côté, plus hautes que ce qu'elles entourent.
StructureNorme? _norme(List<Trait> traits) {
  if (traits.length < 5) return null;
  final tries = traits.toList()
    ..sort((a, b) => _c(a).left.compareTo(_c(b).left));
  // Une flèche au-dessus ne compte pas : les barres se jugent aux lettres.
  final haut = _mediane(
    traits.map(_c).where((c) => !_plat(c)).map((c) => c.height),
  );
  bool barre(Trait t) {
    final c = _c(t);
    return c.height >= 0.8 * haut &&
        c.width <= 0.3 * c.height &&
        _droit(t, c.height);
  }

  if (!barre(tries[0]) || !barre(tries[1])) return null;
  final barres = [
    for (var i = 2; i < tries.length; i++)
      if (barre(tries[i])) i,
  ];
  // Les deux dernières barres qui se suivent ferment la norme.
  for (var k = 0; k + 1 < barres.length; k++) {
    if (barres[k + 1] != barres[k] + 1) continue;
    if (barres[k] <= 2) continue;
    final ecart = _c(tries[barres[k + 1]]).left - _c(tries[barres[k]]).right;
    if (ecart > 0.6 * haut) continue;
    return StructureNorme(
      tries.sublist(2, barres[k]),
      tries.sublist(barres[k + 1] + 1),
    );
  }
  return null;
}

/// Un long trait plat au-dessus de lettres, avec sa pointe à droite ou sans.
StructureFleche? _fleche(List<Trait> traits) {
  final tries = traits.toList()..sort((a, b) => _c(a).top.compareTo(_c(b).top));
  for (final fleche in tries) {
    final f = _c(fleche);
    if (f.height > 0.45 * f.width || f.width < 24) continue;
    var lettres = false;
    final dessous = <Trait>[];
    final pointes = <Trait>[];
    final queue = <Trait>[];
    for (final t in traits) {
      if (identical(t, fleche)) continue;
      final c = _c(t);
      // Une flèche coiffe souvent ses lettres de près, parfois les touche.
      final auDessus = c.center.dy < f.center.dy + 4;
      if (auDessus) {
        pointes.add(t);
      } else if (c.center.dx >= f.left - 8 && c.center.dx <= f.right + 8) {
        dessous.add(t);
        if (!_plat(c)) lettres = true;
      } else {
        queue.add(t);
      }
    }
    // Le trait du haut d'un `=` n'a qu'un trait plat dessous.
    if (!lettres) continue;
    // Rien au-dessus sauf la pointe, près du bout droit : sinon, une fraction.
    final pointeAuBout = pointes.every((p) {
      final c = _c(p);
      return c.center.dx >= f.left + 0.6 * f.width && c.width <= 0.6 * f.width;
    });
    if (!pointeAuBout) continue;
    final nom = cadreDuGroupe(dessous);
    if (nom.center.dy < f.bottom) continue;
    if (f.width < 0.6 * nom.width) continue;
    // Une fraction a sa barre au milieu : elle a de l'encre au-dessus. Ici, le
    // trait coiffe le nom.
    if (nom.left < f.left - 0.5 * f.width) continue;
    return StructureFleche(dessous, queue);
  }
  return null;
}

/// Une parenthèse : haute, étroite, le ventre d'un côté. `1` s'ouvre vers la
/// droite pour `(`, vers la gauche pour `)`.
int _parenthese(Trait t, double hauteur) {
  final s = [for (final p in t.points) p.position];
  if (s.length < 3) return 0;
  final c = _c(t);
  if (c.height < 0.5 * hauteur || c.width > 0.6 * c.height) return 0;
  // Le ventre, pas le milieu des points : un trait commencé lentement a
  // beaucoup de points en haut.
  if (c.left < math.min(s.first.dx, s.last.dx) - 0.1 * c.height) return 1;
  if (c.right > math.max(s.first.dx, s.last.dx) + 0.1 * c.height) return -1;
  return 0;
}

/// `A(8;-1)` : une lettre, `(`, deux nombres séparés par `;` ou `,`, `)`.
/// Le modèle y lit `A(8i-1)` ou `β(5,0)` (Pad 7) : le `;` se voit au trait
/// qui descend sous les chiffres, et chaque nombre se lit comme une case.
StructurePoint? _point(List<Trait> traits) {
  final hauteur = cadreDuGroupe(traits).height;
  final tries = traits.toList()
    ..sort((a, b) => _c(a).left.compareTo(_c(b).left));
  final ouvrante = tries.where((t) => _parenthese(t, hauteur) == 1).firstOrNull;
  if (ouvrante == null) return null;
  final fermante = tries
      .where((t) => _parenthese(t, hauteur) == -1)
      .where((t) => _c(t).left > _c(ouvrante).right)
      // La dernière : un `5` a le ventre d'une `)` (Pad 7).
      .lastOrNull;
  if (fermante == null) return null;
  final (o, f) = (_c(ouvrante), _c(fermante));
  final nom = [
    for (final t in tries)
      if (_c(t).center.dx < o.left) t,
  ];
  // Un seul signe devant : une lettre, pas `f` de `f(2;3)` ni un mot.
  if (nom.isEmpty || _glyphes(nom).length != 1) return null;
  if (cadreDuGroupe(nom).height < 0.5 * o.height) return null;
  final dedans = [
    for (final t in tries)
      if (!identical(t, ouvrante) &&
          !identical(t, fermante) &&
          _c(t).center.dx > o.right &&
          _c(t).center.dx < f.left)
        t,
  ];
  final queue = [
    for (final t in tries)
      if (_c(t).center.dx > f.right) t,
  ];
  if (dedans.length < 2) return null;
  // Le séparateur : un signe étroit qui descend sous les chiffres.
  final bas = _mediane(
    dedans.map(_c).where((c) => !_plat(c)).map((c) => c.bottom),
  );
  final haut = _mediane(
    dedans.map(_c).where((c) => !_plat(c)).map((c) => c.height),
  );
  final glyphes = _glyphes(dedans);
  final separateurs = [
    for (var i = 1; i < glyphes.length - 1; i++)
      if (cadreDuGroupe(glyphes[i]).width <= 0.45 * haut &&
          cadreDuGroupe(glyphes[i]).bottom > bas + 0.2 * haut &&
          cadreDuGroupe(glyphes[i]).height <= 1.4 * haut)
        i,
  ];
  if (separateurs.length != 1) return null;
  final k = separateurs.single;
  return StructurePoint(
    nom,
    [for (final g in glyphes.take(k)) ...g],
    [for (final g in glyphes.skip(k + 1)) ...g],
    queue,
  );
}

/// Deux grands traits qui se font face, et des lignes de cases entre eux.
StructureMatrice? _matrice(List<Trait> traits) {
  final haut = cadreDuGroupe(traits).height;
  final grands = traits.where((t) {
    final c = _c(t);
    return c.height >= 0.6 * haut && c.width <= 0.5 * c.height;
  }).toList()..sort((a, b) => _c(a).left.compareTo(_c(b).left));
  if (grands.length < 2) return null;
  final (g, d) = (grands.first, grands.last);
  final (cg, cd) = (_c(g), _c(d));
  final dedans = <Trait>[];
  final tete = <Trait>[];
  final queue = <Trait>[];
  for (final t in traits) {
    if (identical(t, g) || identical(t, d)) continue;
    final x = _c(t).center.dx;
    if (x < cg.center.dx) {
      tete.add(t);
    } else if (x > cd.center.dx) {
      queue.add(t);
    } else {
      dedans.add(t);
    }
  }
  if (dedans.length < 2) return null;

  // Les lignes : les cœurs des traits qui se chevauchent en hauteur.
  final parY = dedans.toList()
    ..sort((a, b) => _c(a).center.dy.compareTo(_c(b).center.dy));
  final lignes = <List<Trait>>[];
  double? bas;
  for (final t in parY) {
    final c = _c(t);
    final demi = math.max(0.35 * c.height, 4);
    if (bas == null || c.center.dy - demi > bas) {
      lignes.add([]);
      bas = c.center.dy + demi;
    } else {
      bas = math.max(bas, c.center.dy + demi);
    }
    lignes.last.add(t);
  }
  if (lignes.length < 2) return null;

  final hauteur = _mediane(
    dedans.map(_c).where((c) => !_plat(c)).map((c) => c.height),
  );
  final decoupees = [for (final l in lignes) _colonnes(l, hauteur)];
  final comptes = decoupees.map((l) => l.length).toList()..sort();
  final colonnes = comptes[comptes.length ~/ 2];
  final cases = <List<List<Trait>>>[];
  for (final l in decoupees) {
    if (l.length < colonnes) return null;
    cases.add(_fondre(l, colonnes));
  }
  // `⁻¹` écrit haut après la parenthèse : un exposant, pas `- 1` (Pad 7).
  final haute =
      math.min(cg.top, cd.top) + 0.35 * math.max(cg.height, cd.height);
  final exposant = [
    for (final t in queue)
      if (_c(t).bottom < haute) t,
  ];
  return StructureMatrice(tete, cases, [
    for (final t in queue)
      if (!exposant.contains(t)) t,
  ], exposant: exposant);
}

/// Les cases d'une ligne : un écart net les sépare. Un signe moins, plat, va
/// toujours avec ce qui le suit.
List<List<Trait>> _colonnes(List<Trait> ligne, double hauteur) {
  final tries = ligne.toList()
    ..sort((a, b) => _c(a).left.compareTo(_c(b).left));
  final cases = <List<Trait>>[];
  for (final t in tries) {
    final c = _c(t);
    // Un moins commence une case : `-2 -8` fait deux cases, même serrées. La
    // barre d'un 7 ou d'un 4 tombe, elle, sur son chiffre.
    final surLeChiffre =
        cases.isNotEmpty && c.left < cadreDuGroupe(cases.last).right;
    final colle =
        cases.isNotEmpty &&
        (surLeChiffre ||
            (!_plat(c) &&
                !_plat(_c(cases.last.last)) &&
                c.left - cadreDuGroupe(cases.last).right < 0.45 * hauteur));
    final apresMoins =
        cases.isNotEmpty &&
        _plat(_c(cases.last.last)) &&
        c.left - _c(cases.last.last).right < 1.2 * hauteur;
    if (colle || apresMoins) {
      cases.last.add(t);
    } else {
      cases.add([t]);
    }
  }
  return cases;
}

/// Une ligne qui a trop de cases : on rapproche les plus proches.
List<List<Trait>> _fondre(List<List<Trait>> ligne, int colonnes) {
  final cases = ligne.toList();
  while (cases.length > colonnes) {
    var meilleur = 0;
    var ecart = double.infinity;
    for (var i = 0; i + 1 < cases.length; i++) {
      final e =
          cadreDuGroupe(cases[i + 1]).left - cadreDuGroupe(cases[i]).right;
      if (e < ecart) (meilleur, ecart) = (i, e);
    }
    cases
      ..[meilleur] = [...cases[meilleur], ...cases[meilleur + 1]]
      ..removeAt(meilleur + 1);
  }
  return cases;
}

/// `d e t`, `\alpha +`, `c t +`, `\det` : le nom écrit devant une matrice.
bool ressembleADet(String tete) {
  final t = tete.replaceAll(RegExp(r'\s'), '').replaceAll('+', '');
  if (t.isEmpty) return false;
  if (RegExp(r'\\(det|alpha|delta)').hasMatch(t)) return true;
  // `\tau l e t`, `\phi e^{\pi}` : des lettres seules, sans chiffre ni signe,
  // juste devant une matrice : on n'écrit guère que `det` ainsi.
  return RegExp(r'^[a-zA-Z\\^{}]{2,16}$').hasMatch(t);
}

/// Seuls, un `=` ou un `-` trompent le modèle : ils se voient sur les traits.
String? _signeSimple(List<Trait> traits) {
  final cadres = traits.map(_c).toList();
  if (!cadres.every(_plat)) return null;
  if (cadres.length == 1) return '-';
  if (cadres.length == 2) {
    final (a, b) = (cadres[0], cadres[1]);
    final recouvrement = math.min(a.right, b.right) - math.max(a.left, b.left);
    final empiles = (a.center.dy - b.center.dy).abs() > 4;
    if (empiles && recouvrement > 0.4 * math.min(a.width, b.width)) {
      return '=';
    }
  }
  return null;
}

/// Lit [traits] par morceaux, si une structure s'y voit ; sinon `null`. Un
/// morceau illisible rend `null` : le modèle lira alors le tout.
Future<String?> lireStructure(Lecteur lecteur, List<Trait> traits) async {
  final structure = trouverStructure(traits);
  if (structure == null) return null;

  Future<String> morceau(List<Trait> t) async => t.isEmpty
      ? ''
      : (_signeSimple(t) ?? await _lireMorceau(lecteur, t)).trim();

  switch (structure) {
    case StructureNorme(:final dedans, :final queue):
      final interieur = await morceau(dedans);
      if (interieur.isEmpty) return null;
      return '\\|$interieur\\|${await morceau(queue)}';
    case StructurePoint(
      :final nom,
      :final premier,
      :final second,
      :final queue,
    ):
      final (lettre, ecart) = essayerCapitale(_dessin(nom));
      final lu = ecart < 1.5
          ? lettre
          : _lettreLue(await lecteur.lireCourt(nom));
      if (lu == null) return null;
      final nombres = await _lireLigne(lecteur, [premier, second]);
      if (nombres == null) return null;
      return '$lu(${nombres.join(';')})${await morceau(queue)}';
    case StructureFleche(:final nom, :final queue):
      final lettres = [
        for (final g in _glyphes(nom)) reconnaitreCapitale(_dessin(g)),
      ];
      final parTrace = lettres.contains(null) ? null : lettres.join();
      // Une seule lettre sous une flèche : un vecteur `u`, en minuscule.
      final lu = parTrace != null && parTrace.length <= 2
          ? (parTrace.length == 1 ? parTrace.toLowerCase() : parTrace)
          : (await morceau(nom)).replaceAll(RegExp(r'\s'), '');
      if (!RegExp(r'^[A-Za-z]{1,2}$').hasMatch(lu)) return null;
      return '\\overrightarrow{$lu}${await morceau(queue)}';
    case StructureMatrice(
      :final tete,
      :final cases,
      :final queue,
      :final exposant,
    ):
      final lignes = <String>[];
      for (final ligne in cases) {
        final valeurs = await _lireLigne(lecteur, ligne);
        if (valeurs == null) return null;
        lignes.add(valeurs.join('&'));
      }
      final matrice = '\\begin{pmatrix}${lignes.join(r'\\')}\\end{pmatrix}';
      // Le nom devant : jamais une structure, le `e` de `det` a une barre.
      final avant = tete.isEmpty ? '' : (await lecteur.lire(tete)).trim();
      final puissance = exposant.isEmpty
          ? ''
          : '^{${(await morceau(exposant)).replaceAll(' ', '')}}';
      final apres = '$puissance${await morceau(queue)}';
      final nom = ressembleADet(avant) ? r'\det ' : avant;
      return '$nom$matrice$apres';
  }
}

/// Une capitale lue par le modèle : `β` est un `B` mal lu.
String? _lettreLue(String lu) {
  const proches = {r'\beta': 'B', r'\alpha': 'A', r'\Delta': 'A'};
  final propre = lu.replaceAll(RegExp(r'[\s{}]'), '');
  final proche = proches[propre];
  if (proche != null) return proche;
  return RegExp(r'^[A-Z]$').hasMatch(propre) ? propre : null;
}

Future<String> _lireMorceau(Lecteur lecteur, List<Trait> traits) async =>
    await lireStructure(lecteur, traits) ?? await lecteur.lire(traits);

/// Les traits du moins d'une case : plats, et à gauche de tout le reste.
List<Trait> _signeMoins(List<Trait> kase) {
  final corps = kase.where((t) => !_plat(_c(t))).toList();
  if (corps.isEmpty) return const [];
  final debut = cadreDuGroupe(corps).left;
  return [
    for (final t in kase)
      if (_plat(_c(t)) && _c(t).right <= debut + 0.3 * _c(t).width) t,
  ];
}

/// Combien de signes dans une case : les corps qui ne se chevauchent pas.
int _signes(List<Trait> corps) {
  final tries = corps.map(_c).toList()
    ..sort((a, b) => a.left.compareTo(b.left));
  var n = 0;
  var droite = double.negativeInfinity;
  for (final c in tries) {
    if (_plat(c)) continue;
    if (c.left > droite + 3) n++;
    droite = math.max(droite, c.right);
  }
  return n;
}

/// Les signes d'un morceau : les traits qui se chevauchent en largeur.
List<List<Trait>> _glyphes(List<Trait> traits) {
  final tries = traits.toList()
    ..sort((a, b) => _c(a).left.compareTo(_c(b).left));
  final groupes = <List<Trait>>[];
  for (final t in tries) {
    if (groupes.isNotEmpty &&
        // Deux lettres écrites serrées se touchent presque : il faut qu'elles
        // se chevauchent vraiment pour faire un seul signe.
        _c(t).left <= cadreDuGroupe(groupes.last).right) {
      groupes.last.add(t);
    } else {
      groupes.add([t]);
    }
  }
  return groupes;
}

List<List<Offset>> _dessin(List<Trait> g) => [
  for (final t in g) [for (final p in t.points) p.position],
];

/// Une ligne de matrice. Seul, un chiffre trompe le modèle (`1` lu `Λ`) :
/// on le reconnaît sur son tracé, et les moins se voient. Si un signe résiste,
/// le modèle lit la ligne entière, sans les moins.
Future<List<String>?> _lireLigne(
  Lecteur lecteur,
  List<List<Trait>> ligne,
) async {
  final moins = [for (final kase in ligne) _signeMoins(kase)];
  final corps = [
    for (var i = 0; i < ligne.length; i++)
      [
        for (final t in ligne[i])
          if (!moins[i].contains(t)) t,
      ],
  ];
  final parTrace = <String>[];
  for (var i = 0; i < corps.length; i++) {
    final chiffres = [
      for (final g in _glyphes(corps[i])) reconnaitreChiffre(_dessin(g)),
    ];
    if (chiffres.isEmpty || chiffres.contains(null)) break;
    parTrace.add('${moins[i].isEmpty ? '' : '-'}${chiffres.join()}');
  }
  if (parTrace.length == corps.length) return parTrace;

  final attendus = [for (final c in corps) _signes(c)];
  final total = attendus.fold(0, (s, n) => s + n);
  List<String> signesDe(String lu) =>
      RegExp('[0-9a-zA-Z]')
          .allMatches(lu.replaceAll(RegExp(r'\\[a-zA-Z]+'), ' '))
          .map((m) => m[0]!)
          .toList();
  var signes = signesDe(await lecteur.lire([for (final c in corps) ...c]));
  // Sans ses moins, `8 1` peut se lire `8` (Pad 7) ; avec eux, `8 - 1`.
  if (signes.length != total && moins.any((m) => m.isNotEmpty)) {
    signes = signesDe(await lecteur.lire([for (final k in ligne) ...k]));
  }
  if (signes.length == total) {
    final valeurs = <String>[];
    var k = 0;
    for (var i = 0; i < ligne.length; i++) {
      final v = signes.sublist(k, k + attendus[i]).join();
      k += attendus[i];
      valeurs.add(moins[i].isEmpty ? v : '-$v');
    }
    return valeurs;
  }
  // Le tracé hésite, mais reste proche pour chaque signe : mieux qu'une
  // case lue seule, que le modèle ne sait pas lire (`8` lu `\overbrace`).
  final proches = <String>[];
  for (var i = 0; i < corps.length; i++) {
    final essais = [
      for (final g in _glyphes(corps[i])) essayerChiffre(_dessin(g)),
    ];
    if (essais.isEmpty || essais.any((e) => e.$2 > 1.3)) break;
    proches.add(
      '${moins[i].isEmpty ? '' : '-'}${essais.map((e) => e.$1).join()}',
    );
  }
  if (proches.length == corps.length) return proches;
  // Sinon, case par case, sur une image large.
  final valeurs = <String>[];
  for (final kase in ligne) {
    final v = _case(await lecteur.lireCourt(kase));
    if (!_caseLisible(v)) return null;
    valeurs.add(v);
  }
  return valeurs;
}

/// Un nombre, une lettre, une courte expression : pas le bruit d'une case mal
/// lue, `\overbrace { \alpha }` ou `\frac { 5 } { - }`.
bool _caseLisible(String v) {
  if (v.isEmpty || v.contains(r'\overbrace') || v.contains(r'\vphantom')) {
    return false;
  }
  try {
    analyserLatex(v);
    return true;
  } on ErreurLatex {
    return false;
  }
}

/// Une case lue seule : `- 5`, `4`, parfois avec un habillage inutile.
String _case(String lu) =>
    lu.replaceAll(RegExp(r'\\(left|right)\b'), '').trim();

/// La lecture la plus fiable : par structure si elle se voit.
Future<String> lireAuMieux(Lecteur lecteur, List<Trait> traits) async {
  final structuree = await lireStructure(lecteur, traits);
  if (structuree != null && plausibilite(structuree) > -50) return structuree;
  return await lecteur.lire(traits);
}

/// Les signes plats d'une ligne, de gauche à droite : `=` (deux traits
/// plats l'un sur l'autre) ou `-`. Une barre de fraction, avec de l'encre
/// dessus et dessous, n'en est pas un.
List<String> signesPlats(List<Trait> traits) {
  final cadres = traits.map(_c).toList();
  // La barre d'un `t` ou d'un `7` est plate, mais croise un autre trait.
  // Et un signe est fin : un mot cursif, `longueur`, est plat mais épais.
  final ligne = cadreDuGroupe(traits).height;
  final debout = cadres.where((c) => !_plat(c)).toList();
  final plats = [
    for (final c in cadres)
      if (_plat(c) &&
          c.width >= 6 &&
          c.height <= 0.25 * ligne &&
          !debout.any(c.deflate(1).overlaps))
        c,
  ]..sort((a, b) => a.left.compareTo(b.left));
  bool barre(Rect p) {
    bool dessus(Rect c) =>
        c.center.dx > p.left && c.center.dx < p.right && c.bottom < p.top;
    bool dessous(Rect c) =>
        c.center.dx > p.left && c.center.dx < p.right && c.top > p.bottom;
    final autres = cadres.where((c) => !identical(c, p)).toList();
    return autres.any(dessus) && autres.any(dessous);
  }

  final signes = <String>[];
  final pris = <Rect>{};
  for (final p in plats) {
    if (pris.contains(p) || barre(p)) continue;
    final jumeau = plats
        .where((q) => !identical(q, p) && !pris.contains(q))
        .where((q) {
          final commun = math.min(p.right, q.right) - math.max(p.left, q.left);
          final ecart = (q.center.dy - p.center.dy).abs();
          return commun > 0.5 * math.min(p.width, q.width) &&
              ecart > 2 &&
              ecart < 0.9 * math.max(p.width, q.width);
        })
        .firstOrNull;
    if (jumeau != null) {
      pris.addAll([p, jumeau]);
      signes.add('=');
    } else {
      pris.add(p);
      signes.add('-');
    }
  }
  return signes;
}

/// `e^x = 7` lu `e^{x} - 7` (Pad 7) : le trait du dessus, arrondi, a échappé
/// au modèle. Si les traits montrent un `=` que la lecture n'a pas, et un
/// moins de trop à sa place, ce moins redevient `=`.
String redresserEgal(List<Trait> traits, String latex) {
  if (latex.contains('=')) return latex;
  final signes = signesPlats(traits);
  if (signes.where((s) => s == '=').length != 1) return latex;
  final moins = RegExp(r'(?<!\\)-').allMatches(latex).toList();
  final moinsTraces = signes.where((s) => s == '-').length;
  if (moins.length != moinsTraces + 1) return latex;
  final rang = signes.indexOf('=');
  final m = moins[rang];
  return latex.replaceRange(m.start, m.end, '=');
}
