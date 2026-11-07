import 'dart:math' as math;
import 'dart:ui';

import 'package:fikajiana/comprendre/blocs.dart';
import 'package:fikajiana/comprendre/signes.dart';
import 'package:fikajiana/comprendre/structure.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana_math/fikajiana_math.dart';

/// Une ligne lue sur son tracé seul, sans le modèle (ADR 0035, idée de
/// Mikajy) : chiffres, capitales, `+ − = × ( )` et exposants. Quelques
/// millisecondes au lieu de 300, et le `1` d'Antsa n'est plus un `Λ`.
///
/// Rend `null` dès qu'un signe doute : le modèle lit alors la ligne entière.
String? lireAuTrace(List<Trait> traits) {
  final nets = [
    for (final t in traits)
      if (cadreDuGroupe([t]).width >= 5 || cadreDuGroupe([t]).height >= 5) t,
  ];
  if (nets.isEmpty) return null;
  // Une barre de fraction, de l'encre dessus et dessous : au modèle.
  for (final t in nets) {
    final c = _c(t);
    if (!_plat(c)) continue;
    var dessus = false;
    var dessous = false;
    for (final autre in nets) {
      final a = _c(autre);
      if (identical(autre, t) ||
          a.center.dx < c.left ||
          a.center.dx > c.right) {
        continue;
      }
      if (a.bottom <= c.top + 2) dessus = true;
      if (a.top >= c.bottom - 2) dessous = true;
    }
    if (dessus && dessous) return null;
  }
  final glyphes = _grouper(nets);
  if (glyphes.length < 2) return null;
  final cadres = [for (final g in glyphes) cadreDuGroupe(g)];
  final hauteurs = [
    for (final c in cadres)
      if (c.height > 0.5 * c.width) c.height,
  ]..sort();
  if (hauteurs.isEmpty) return null;
  final hauteur = hauteurs[hauteurs.length ~/ 2];
  // Une barre de fraction, une racine : au modèle.
  for (final c in cadres) {
    if (c.height > 1.9 * hauteur) return null;
  }
  final bas = [
    for (final c in cadres)
      if (c.height > 0.5 * c.width && c.height >= 0.7 * hauteur) c.bottom,
  ]..sort();
  if (bas.isEmpty) return null;
  final ligneDeBase = bas[bas.length ~/ 2];

  final sortie = StringBuffer();
  var exposant = false;
  for (var i = 0; i < glyphes.length; i++) {
    final c = cadres[i];
    final signe = _signe(glyphes[i], hauteur);
    if (signe == null) return null;
    final haut =
        c.bottom < ligneDeBase - 0.45 * hauteur &&
        c.height < 0.75 * hauteur &&
        i > 0 &&
        !_operateur(signe);
    if (haut && !exposant) {
      sortie.write('^{');
      exposant = true;
    } else if (!haut && exposant) {
      sortie.write('}');
      exposant = false;
    }
    sortie.write(signe);
  }
  if (exposant) sortie.write('}');
  final latex = sortie.toString();
  // Rien qu'un nombre, ou rien qu'un signe : sans intérêt, et douteux.
  if (!RegExp('[0-9A-Z]').hasMatch(latex)) return null;
  try {
    analyserLatex(latex);
  } on ErreurLatex {
    return null;
  }
  return latex;
}

/// Les signes, de gauche à droite. Un plat ne rejoint un signe que s'il le
/// croise (`+`, `4`, `7`) ou double un autre plat (`=`) : un `=` collé au
/// `8` d'avant reste un `=`.
List<List<Trait>> _grouper(List<Trait> traits) {
  final tries = traits.toList()
    ..sort((a, b) => _c(a).left.compareTo(_c(b).left));
  final groupes = <List<Trait>>[];
  for (final t in tries) {
    final c = _c(t);
    List<Trait>? hote;
    for (final g in groupes.reversed) {
      final cg = cadreDuGroupe(g);
      if (c.left > cg.right) continue;
      if (_plat(c)) {
        final platsSeuls = g.every((x) => _plat(_c(x)));
        final commun = math.min(c.right, cg.right) - math.max(c.left, cg.left);
        if (platsSeuls && commun >= 0.5 * math.min(c.width, cg.width)) {
          hote = g;
        } else if (!platsSeuls &&
            c.center.dx > cg.left &&
            c.center.dx < cg.right &&
            c.center.dy > cg.top &&
            c.center.dy < cg.bottom) {
          hote = g;
        }
      } else if (c.left < cg.right - 0.1 * math.min(c.width, cg.width) ||
          (g.length == 1 && _plat(cg) && c.left < cg.right)) {
        hote = g;
      }
      if (hote != null) break;
    }
    if (hote == null) {
      groupes.add([t]);
    } else {
      hote.add(t);
    }
  }
  return groupes;
}

bool _operateur(String s) => const {'+', '-', '=', r'\times'}.contains(s);

Rect _c(Trait t) => cadreDuGroupe([t]);

bool _plat(Rect c) => c.height <= 0.45 * c.width && c.width >= 6;

bool _debout(Rect c) => c.width <= 0.45 * c.height && c.height >= 6;

/// Un trait presque droit : ses points restent près de la corde.
bool _droit(Trait t) {
  final s = [for (final p in t.points) p.position];
  if (s.length < 2) return true;
  final (a, b) = (s.first, s.last);
  final corde = b - a;
  final longueur = corde.distance;
  if (longueur < 4) return false;
  for (final p in s) {
    final d =
        ((p.dx - a.dx) * corde.dy - (p.dy - a.dy) * corde.dx).abs() / longueur;
    if (d > 0.12 * longueur) return false;
  }
  return true;
}

/// Une diagonale droite : montante (`/`) rend 1, descendante (`\`) -1, 0 sinon.
int _diagonale(Trait t) {
  if (!_droit(t)) return 0;
  final s = [for (final p in t.points) p.position];
  final corde = s.last - s.first;
  if (corde.dx.abs() < 4 || corde.dy.abs() < 4) return 0;
  final pente = corde.dy.abs() / corde.dx.abs();
  if (pente < 0.4 || pente > 2.5) return 0;
  return corde.dx.sign == corde.dy.sign ? -1 : 1;
}

String? _signe(List<Trait> g, double hauteur) {
  final cadres = g.map(_c).toList();
  if (g.length == 1) {
    final t = g.single;
    final c = cadres.single;
    if (_plat(c) && _droit(t)) return '-';
    // Un  seul : une fraction en ligne, que le modèle sait lire.
    if (_diagonale(t) == 1) return null;
    switch (genreParenthese(t, hauteur)) {
      case 1:
        return '(';
      case -1:
        return ')';
    }
    return reconnaitreChiffre([
          [for (final p in t.points) p.position],
        ]) ??
        _capitale(g);
  }
  if (g.length == 2) {
    final (a, b) = (cadres[0], cadres[1]);
    // `=` : deux plats l'un sur l'autre.
    if (_plat(a) && _plat(b) && _droit(g[0]) && _droit(g[1])) {
      final commun = math.min(a.right, b.right) - math.max(a.left, b.left);
      final ecart = (a.center.dy - b.center.dy).abs();
      if (commun >= 0.5 * math.min(a.width, b.width) &&
          ecart >= 2 &&
          ecart <= math.max(a.width, b.width)) {
        return '=';
      }
    }
    // `+` : un plat et un debout qui se croisent vers leurs milieux.
    final (plat, debout) = _plat(a) && _debout(b)
        ? (a, b)
        : _plat(b) && _debout(a)
        ? (b, a)
        : (null, null);
    if (plat != null && debout != null && _droit(g[0]) && _droit(g[1])) {
      final croise =
          debout.center.dx > plat.left + 0.2 * plat.width &&
          debout.center.dx < plat.right - 0.2 * plat.width &&
          plat.center.dy > debout.top + 0.2 * debout.height &&
          plat.center.dy < debout.bottom - 0.2 * debout.height;
      if (croise) return '+';
    }
    // `×` : deux diagonales qui se croisent.
    final (d1, d2) = (_diagonale(g[0]), _diagonale(g[1]));
    if (d1 * d2 == -1 &&
        a.overlaps(b) &&
        (a.center - b.center).distance < 0.5 * math.max(a.width, b.width)) {
      return r'\times';
    }
  }
  return reconnaitreChiffre([
        for (final t in g) [for (final p in t.points) p.position],
      ]) ??
      _capitale(g);
}

String? _capitale(List<Trait> g) => reconnaitreCapitale([
  for (final t in g) [for (final p in t.points) p.position],
]);
