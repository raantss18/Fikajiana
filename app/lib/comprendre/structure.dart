import 'dart:math' as math;
import 'dart:ui';

import 'package:fikajiana/comprendre/blocs.dart';
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
  const new(this.tete, this.cases, this.queue);
  final List<Trait> tete;
  final List<List<List<Trait>>> cases;
  final List<Trait> queue;
}

/// `→` au-dessus de `AB`, et ce qui suit.
class StructureFleche extends Structure {
  const new(this.nom, this.queue);
  final List<Trait> nom;
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

bool _plat(Rect c) => c.height <= 0.35 * c.width;

/// La structure qui se voit sur ces traits, ou `null` : une ligne ordinaire.
Structure? trouverStructure(List<Trait> traits) {
  if (traits.length < 3) return null;
  return _norme(traits) ?? _fleche(traits) ?? _matrice(traits);
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
    return c.height >= 0.8 * haut && c.width <= 0.3 * c.height;
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
      } else {
        queue.add(t);
      }
    }
    if (dessous.isEmpty) continue;
    // Rien au-dessus sauf la pointe, près du bout droit : sinon, une fraction.
    final pointeAuBout = pointes.every((p) {
      final c = _c(p);
      return c.center.dx >= f.left + 0.6 * f.width && c.width <= 0.4 * f.width;
    });
    if (!pointeAuBout) continue;
    final nom = cadreDuGroupe(dessous);
    if (nom.center.dy < f.bottom) continue;
    if (f.width < 0.6 * nom.width) continue;
    // Une fraction a sa barre au milieu : elle a de l'encre au-dessus. Ici, le
    // trait coiffe le nom.
    if (nom.left < f.left - 0.3 * f.width) continue;
    return StructureFleche(dessous, queue);
  }
  return null;
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
  return StructureMatrice(tete, cases, queue);
}

/// Les cases d'une ligne : un écart net les sépare. Un signe moins, plat, va
/// toujours avec ce qui le suit.
List<List<Trait>> _colonnes(List<Trait> ligne, double hauteur) {
  final tries = ligne.toList()
    ..sort((a, b) => _c(a).left.compareTo(_c(b).left));
  final cases = <List<Trait>>[];
  for (final t in tries) {
    final c = _c(t);
    // Un moins commence une case : `-2 -8` fait deux cases, même serrées.
    final colle =
        cases.isNotEmpty &&
        !_plat(c) &&
        !_plat(_c(cases.last.last)) &&
        c.left - cadreDuGroupe(cases.last).right < 0.45 * hauteur;
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
  // `\tau l e t` : la matrice suit aussitôt, et rien n'est un nombre.
  return RegExp(r'^[a-zA-Z\\]{2,12}$').hasMatch(t) &&
      RegExp('[dt]').hasMatch(t);
}

/// Lit [traits] par morceaux, si une structure s'y voit ; sinon `null`. Un
/// morceau illisible rend `null` : le modèle lira alors le tout.
Future<String?> lireStructure(Lecteur lecteur, List<Trait> traits) async {
  final structure = trouverStructure(traits);
  if (structure == null) return null;

  Future<String> morceau(List<Trait> t) async =>
      t.isEmpty ? '' : (await _lireMorceau(lecteur, t)).trim();
  // Une case est courte : déformée en carré, elle ne se lit plus.
  Future<String> casesCourte(List<Trait> t) async =>
      (await lecteur.lireCourt(t)).trim();

  switch (structure) {
    case StructureNorme(:final dedans, :final queue):
      final interieur = await morceau(dedans);
      if (interieur.isEmpty) return null;
      return '\\|$interieur\\|${await morceau(queue)}';
    case StructureFleche(:final nom, :final queue):
      final lu = (await morceau(nom)).replaceAll(RegExp(r'\s'), '');
      if (!RegExp(r'^[A-Za-z]{1,2}$').hasMatch(lu)) return null;
      return '\\overrightarrow{$lu}${await morceau(queue)}';
    case StructureMatrice(:final tete, :final cases, :final queue):
      final lignes = <String>[];
      for (final ligne in cases) {
        final valeurs = <String>[];
        for (final c in ligne) {
          final v = _case(await casesCourte(c));
          if (!_caseLisible(v)) return null;
          valeurs.add(v);
        }
        lignes.add(valeurs.join('&'));
      }
      final matrice = '\\begin{pmatrix}${lignes.join(r'\\')}\\end{pmatrix}';
      final avant = await morceau(tete);
      final apres = await morceau(queue);
      final nom = ressembleADet(avant) ? r'\det ' : avant;
      return '$nom$matrice$apres';
  }
}

Future<String> _lireMorceau(Lecteur lecteur, List<Trait> traits) async =>
    await lireStructure(lecteur, traits) ?? await lecteur.lire(traits);

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
