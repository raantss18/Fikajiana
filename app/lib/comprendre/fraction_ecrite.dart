import 'dart:math' as math;
import 'dart:ui';

import 'package:fikajiana/encre/encre.dart';

/// Une fraction écrite en ligne, `1/3`, se redresse : **les traits de la
/// personne** se déplacent, le 1 au-dessus, la barre à plat, le 3 dessous.
class FractionsRedressees {
  const new(this.latex, this.traits);

  /// La lecture, avec `\frac{1}{3}`.
  final String latex;

  /// Les traits qui changent, par identifiant.
  final Map<int, Trait> traits;
}

/// `1/3`, `12/5`, `x/2` ; pas `sin/2`, ni ce qui suit une commande LaTeX.
final _fraction = RegExp(
  r'(?<![\\a-zA-Z0-9.])(\d+|[a-zA-Z])/(\d+|[a-zA-Z])(?![a-zA-Z0-9.])',
);

/// Rend de quoi redresser les fractions de [latex], ou `null` si quelque chose
/// ne colle pas entre la lecture et les traits : dans le doute, rien ne bouge.
FractionsRedressees? redresserFractions(List<Trait> traits, String latex) {
  final fractions = _fraction.allMatches(latex).toList();
  if (fractions.isEmpty) return null;
  // Une autre barre dans la lecture, comme `(x+1)/2` : on ne sait pas la placer.
  if ('/'.allMatches(latex).length != fractions.length) return null;
  final barres = traits.where(_estBarre).toList()
    ..sort((a, b) => _cadre(a).center.dx.compareTo(_cadre(b).center.dx));
  if (barres.length != fractions.length) return null;

  var courants = {for (final t in traits) t.id: t};
  // De droite à gauche : redresser l'une ne dérange que ce qui la suit.
  for (var i = fractions.length - 1; i >= 0; i--) {
    final suivants = _redresser(
      courants,
      barres[i].id,
      fractions[i][1]!.length,
      fractions[i][2]!.length,
    );
    if (suivants == null) return null;
    courants = suivants;
  }
  final ecrit = latex.replaceAllMapped(
    _fraction,
    (m) => '\\frac{${m[1]}}{${m[2]}}',
  );
  return FractionsRedressees(ecrit, {
    for (final t in traits)
      if (!identical(courants[t.id], t)) t.id: courants[t.id]!,
  });
}

Rect _cadre(Trait t) {
  var (g, h, d, b) = (
    t.points.first.x,
    t.points.first.y,
    t.points.first.x,
    t.points.first.y,
  );
  for (final p in t.points) {
    g = math.min(g, p.x);
    d = math.max(d, p.x);
    h = math.min(h, p.y);
    b = math.max(b, p.y);
  }
  return Rect.fromLTRB(g, h, d, b);
}

/// Un trait droit qui monte vers la droite : la barre d'une fraction en ligne.
bool _estBarre(Trait t) {
  final (a, b) = (t.points.first, t.points.last);
  final (dx, dy) = (b.x - a.x, b.y - a.y);
  final longueur = math.sqrt(dx * dx + dy * dy);
  if (longueur < 10) return false;
  // Monter vers la droite : dx et dy de signes contraires, à l'écran.
  if (dx * dy >= 0) return false;
  final pente = math.atan2(dy.abs(), dx.abs());
  if (pente < 35 * math.pi / 180) return false;
  // À 4° de la verticale près, c'est un 1 ou un l plutôt qu'une barre.
  if (pente > 86 * math.pi / 180) return false;
  for (final p in t.points) {
    final ecart = ((p.x - a.x) * dy - (p.y - a.y) * dx).abs() / longueur;
    if (ecart > 0.12 * longueur) return false;
  }
  return true;
}

/// Regroupe les traits qui se chevauchent en largeur : un signe, 4 en a deux.
List<List<Trait>> _signes(List<Trait> traits) {
  final tries = traits.toList()
    ..sort((a, b) => _cadre(a).left.compareTo(_cadre(b).left));
  final signes = <List<Trait>>[];
  var droite = double.negativeInfinity;
  for (final t in tries) {
    final c = _cadre(t);
    if (signes.isEmpty || c.left > droite) {
      signes.add([t]);
      droite = c.right;
    } else {
      signes.last.add(t);
      droite = math.max(droite, c.right);
    }
  }
  return signes;
}

Map<int, Trait>? _redresser(
  Map<int, Trait> traits,
  int idBarre,
  int chiffresHaut,
  int chiffresBas,
) {
  final barre = traits[idBarre]!;
  final cb = _cadre(barre);
  final autres = traits.values.where((t) => t.id != idBarre).toList();
  final avant = _signes(
    autres.where((t) => _cadre(t).center.dx < cb.center.dx).toList(),
  );
  final apres = _signes(
    autres.where((t) => _cadre(t).center.dx >= cb.center.dx).toList(),
  );
  if (avant.length < chiffresHaut || apres.length < chiffresBas) return null;
  final haut = avant.sublist(avant.length - chiffresHaut).expand((s) => s);
  final bas = apres.sublist(0, chiffresBas).expand((s) => s).toList();
  final suite = apres.sublist(chiffresBas).expand((s) => s).toList();

  Rect union(Iterable<Trait> l) =>
      l.map(_cadre).reduce((a, b) => a.expandToInclude(b));
  final (ch, cd) = (union(haut), union(bas));
  const reduction = 0.85;
  const espace = 7.0;
  final demi = math.max(ch.width, cd.width) * reduction / 2 + espace;
  final milieu = ch.left + demi;
  final y = cb.center.dy;
  final nouveaux = Map<int, Trait>.of(traits);

  void placer(Iterable<Trait> liste, Rect source, Offset centre) {
    for (final t in liste) {
      nouveaux[t.id] = Trait.deplace(t, [
        for (final p in t.points)
          PointEncre(
            centre.dx + (p.x - source.center.dx) * reduction,
            centre.dy + (p.y - source.center.dy) * reduction,
            p.pression,
            tempsMs: p.tempsMs,
          ),
      ]);
    }
  }

  placer(haut, ch, Offset(milieu, y - espace - ch.height * reduction / 2));
  placer(bas, cd, Offset(milieu, y + espace + cd.height * reduction / 2));
  final n = barre.points.length;
  nouveaux[idBarre] = Trait.deplace(barre, [
    for (var i = 0; i < n; i++)
      PointEncre(
        milieu - demi + 2 * demi * (n == 1 ? 0 : i / (n - 1)),
        y,
        barre.points[i].pression,
        tempsMs: barre.points[i].tempsMs,
      ),
  ]);
  // Ce qui suit se resserre, pour que le `=` reste près de la fraction.
  final decalage = milieu + demi - cd.right;
  for (final t in suite) {
    nouveaux[t.id] = Trait.deplace(t, [
      for (final p in t.points)
        PointEncre(p.x + decalage, p.y, p.pression, tempsMs: p.tempsMs),
    ]);
  }
  return nouveaux;
}
