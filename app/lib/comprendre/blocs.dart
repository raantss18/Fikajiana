import 'dart:ui';

import 'package:fikajiana/encre/encre.dart';

/// Écart maximal entre deux traits d'une même expression, en pixels de page.
const double _ecartHorizontal = 70;
const double _ecartVertical = 45;

Rect _cadre(Trait trait) {
  final points = trait.points;
  var (g, h, d, b) = (
    points.first.x,
    points.first.y,
    points.first.x,
    points.first.y,
  );
  for (final p in points) {
    if (p.x < g) g = p.x;
    if (p.x > d) d = p.x;
    if (p.y < h) h = p.y;
    if (p.y > b) b = p.y;
  }
  return Rect.fromLTRB(g, h, d, b);
}

/// Regroupe les traits proches : chaque groupe est une expression à lire.
/// Les formes nettes sont des dessins : elles n'en font pas partie.
List<List<Trait>> grouperTraits(List<Trait> traits) {
  final ecrits = traits.where((t) => t.forme == null).toList();
  final cadres = ecrits.map(_cadre).toList();
  final parents = List<int>.generate(ecrits.length, (i) => i);
  int racine(int i) {
    var r = i;
    while (parents[r] != r) {
      r = parents[r];
    }
    return r;
  }

  for (var i = 0; i < ecrits.length; i++) {
    for (var j = 0; j < i; j++) {
      final proche = cadres[i]
          .inflate(_ecartHorizontal / 2)
          .overlaps(cadres[j].inflate(_ecartHorizontal / 2));
      final vertical =
          (cadres[i].top - cadres[j].bottom) <= _ecartVertical &&
          (cadres[j].top - cadres[i].bottom) <= _ecartVertical;
      if (proche && vertical) parents[racine(i)] = racine(j);
    }
  }
  final groupes = <int, List<Trait>>{};
  for (var i = 0; i < ecrits.length; i++) {
    (groupes[racine(i)] ??= []).add(ecrits[i]);
  }
  return groupes.values.toList();
}

Rect cadreDuGroupe(List<Trait> groupe) =>
    groupe.map(_cadre).reduce((a, b) => a.expandToInclude(b));

String cleDuGroupe(List<Trait> groupe) {
  final ids = groupe.map((t) => t.id).toList()..sort();
  return ids.join(',');
}
