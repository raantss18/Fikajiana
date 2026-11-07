import 'dart:math' as math;
import 'dart:ui';

import 'package:fikajiana/encre/encre.dart';

/// Écart maximal entre deux traits d'une même expression, en pixels de page.
const double _ecartHorizontal = 70;
const double _ecartVertical = 45;
const double _marge = 8;
const double _hauteurMinimale = 40;

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
      // Plus on écrit grand, plus les signes d'une expression s'écartent.
      final ecart = math.max(
        _ecartHorizontal,
        1.2 * math.max(cadres[i].height, cadres[j].height),
      );
      final proche = cadres[i]
          .inflate(ecart / 2)
          .overlaps(cadres[j].inflate(ecart / 2));
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
  return [for (final g in groupes.values) ..._separerLignes(g)];
}

/// Deux lignes écrites serrées se touchent, par la queue d'un `g` par exemple :
/// le modèle les lirait comme une seule. On les sépare, sauf si un trait les
/// relie : parenthèse, accolade, barre de fraction.
List<List<Trait>> _separerLignes(List<Trait> groupe) {
  if (groupe.length < 6) return [groupe];
  final cadres = {for (final t in groupe) t: _cadre(t)};
  final largeurTotale = cadreDuGroupe(groupe).width;

  // Le cœur de chaque trait : sans la queue ni les jambages.
  final tries = groupe.toList()
    ..sort((a, b) => cadres[a]!.center.dy.compareTo(cadres[b]!.center.dy));
  final rangs = <List<Trait>>[];
  double? bas;
  for (final t in tries) {
    final c = cadres[t]!;
    final demi = math.max(0.3 * c.height, 5);
    if (bas == null || c.center.dy - demi > bas) {
      rangs.add([]);
      bas = c.center.dy + demi;
    } else {
      bas = math.max(bas, c.center.dy + demi);
    }
    rangs.last.add(t);
  }

  rang.length >= 3 && cadreDuGroupe(rang).width >= 0.3 * largeurTotale;
  bool estLigne(List<Trait> rang) =>
      rang.length >= 3 && cadreDuGroupe(rang).width >= 0.3 * largeurTotale;
  final lignes = rangs.where(estLigne).toList();
  if (lignes.length < 2) return [groupe];

  double milieu(List<Trait> rang) => cadreDuGroupe(rang).center.dy;
  for (var i = 1; i < lignes.length; i++) {
    final (haut, dessous) = (milieu(lignes[i - 1]), milieu(lignes[i]));
    // Un trait qui traverse les deux lignes : parenthèse ou accolade.
    if (groupe.any((t) {
      final c = cadres[t]!;
      return c.top <= haut && c.bottom >= dessous;
    })) {
      return [groupe];
    }
    // Une barre entre les deux : c'est une fraction.
    final largeur = math.min(
      cadreDuGroupe(lignes[i - 1]).width,
      cadreDuGroupe(lignes[i]).width,
    );
    if (groupe.any((t) {
      final c = cadres[t]!;
      return c.center.dy > haut &&
          c.center.dy < dessous &&
          c.height <= 0.3 * c.width &&
          c.width >= 0.6 * largeur;
    })) {
      return [groupe];
    }
  }

  // Les petits rangs (exposants, tirets) vont à la ligne la plus proche.
  final sortie = [
    for (final l in lignes) <Trait>[...l],
  ];
  for (final rang in rangs.where((r) => !estLigne(r))) {
    final y = milieu(rang);
    var meilleure = 0;
    for (var i = 1; i < lignes.length; i++) {
      if ((milieu(lignes[i]) - y).abs() <
          (milieu(lignes[meilleure]) - y).abs()) {
        meilleure = i;
      }
    }
    sortie[meilleure].addAll(rang);
  }
  return sortie;
}

Rect cadreDuGroupe(List<Trait> groupe) =>
    groupe.map(_cadre).reduce((a, b) => a.expandToInclude(b));

/// Ce nouveau [groupe] modifie-t-il un bloc déjà lu ?
///
/// Oui s'il le touche. Oui aussi s'il le continue sur la même ligne, juste à sa
/// droite, tant que le bloc n'est pas [ferme] par un `=`. Sinon c'est un autre
/// calcul : le résultat du bloc reste en place.
bool prolonge(Rect bloc, Rect groupe, {required bool ferme}) {
  final zone = bloc.inflate(_marge);
  if (zone.overlaps(groupe)) {
    // La queue d'un `g` qui descend ne fait pas de la ligne d'en dessous une
    // suite : il faut que le nouveau groupe soit surtout dans le bloc.
    final commun = zone.intersect(groupe);
    if (commun.height >= 0.5 * groupe.height) return true;
    if (groupe.center.dy <= zone.bottom) return true;
  }
  if (ferme) return false;
  final milieu = groupe.center.dy;
  final memeLigne = milieu >= bloc.top && milieu <= bloc.bottom;
  final hauteur = bloc.height < _hauteurMinimale
      ? _hauteurMinimale
      : bloc.height;
  final ecart = groupe.left - bloc.right;
  return memeLigne && ecart >= 0 && ecart <= 1.5 * hauteur;
}
