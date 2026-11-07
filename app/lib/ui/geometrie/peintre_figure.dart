import 'dart:math' as math;

import 'package:fikajiana/geometrie/atelier.dart';
import 'package:fikajiana/geometrie/ecriture_geo.dart';
import 'package:fikajiana/graphe/vue_graphe.dart';
import 'package:fikajiana/ui/graphe/peintre_graphe.dart';
import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter/material.dart';

/// La grille, les objets, puis les points et leurs noms, toujours lisibles.
class PeintreFigure extends CustomPainter {
  const new({
    required this.atelier,
    required this.vue,
    required this.fond,
    required this.grille,
    required this.palette,
    required this.choix,
    required this.texte,
    required this.francais,
    this.apercu,
    this.doigt,
    this.courbes,
  });

  /// Les courbes de la Figure, sous les objets, dans le même repère.
  final PeintreGraphe? courbes;

  final Atelier atelier;
  final VueGraphe vue;
  final Color fond;
  final Color grille;

  /// Les couleurs du support : le premier rang est celui des lignes, le
  /// troisième celui des points libres, le quatrième celui des mesures.
  final List<Color> palette;
  final Color choix;
  final TextStyle texte;
  final bool francais;

  /// La construction telle qu'elle serait si le doigt se levait ici.
  final FormeGeo? apercu;
  final Offset? doigt;

  Color _couleur(int id) {
    final rang = atelier.figure.apparence(id).couleur;
    if (rang != null) return palette[rang % palette.length];
    final d = atelier.figure.definition(id);
    if (d is PointLibre || d is PointSur) return palette[2];
    return palette[atelier.figure.categorie(id) == CategorieGeo.nombre ? 3 : 0];
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..drawRect(Offset.zero & size, Paint()..color = fond)
      ..clipRect(Offset.zero & size);
    final courbes = this.courbes;
    if (courbes != null && courbes.courbes.isNotEmpty) {
      // Des courbes se lisent sur des axes gradués.
      courbes.peindreSousLaFigure(canvas, size);
    } else {
      if (atelier.grille) _grille(canvas, size);
      if (atelier.axes) _axes(canvas, size);
    }
    final figure = atelier.figure;
    final choisis = atelier.choisis;
    final selection = atelier.selection;
    final formes = atelier.formes;
    for (final MapEntry(key: id, value: forme) in formes.entries) {
      if (forme == null || !figure.apparence(id).visible) continue;
      final choisi = choisis.contains(id) || selection == id;
      if (atelier.estCandidat(id) && forme is! PointGeo) {
        _forme(
          canvas,
          size,
          forme,
          Paint()
            ..color = choix.withValues(alpha: 0.3)
            ..strokeWidth = 8
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
          pointille: false,
        );
      }
      _forme(
        canvas,
        size,
        forme,
        Paint()
          ..color = choisi ? choix : _couleur(id)
          ..strokeWidth = choisi ? 3.5 : 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
        pointille: figure.apparence(id).pointille,
      );
    }
    final apercu = this.apercu;
    if (apercu != null) {
      _forme(
        canvas,
        size,
        apercu,
        Paint()
          ..color = choix
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
        pointille: true,
      );
    }
    final doigt = this.doigt;
    if (doigt != null) canvas.drawCircle(doigt, 5, Paint()..color = choix);
    for (final MapEntry(key: id, value: forme) in formes.entries) {
      if (forme == null || !figure.apparence(id).visible) continue;
      if (forme is PointGeo) {
        _point(canvas, size, id, forme);
      } else {
        _etiquette(canvas, size, id, forme);
      }
    }
  }

  void _point(Canvas canvas, Size size, int id, PointGeo forme) {
    final figure = atelier.figure;
    final p = vue.versEcran(forme.x, forme.y, size);
    final definition = figure.definition(id);
    final bouge = definition is PointLibre || definition is PointSur;
    if (atelier.choisis.contains(id) || atelier.selection == id) {
      canvas.drawCircle(p, 11, Paint()..color = choix);
    } else if (atelier.estCandidat(id)) {
      canvas.drawCircle(p, 11, Paint()..color = choix.withValues(alpha: 0.3));
    }
    canvas
      ..drawCircle(p, bouge ? 7 : 5, Paint()..color = fond)
      ..drawCircle(p, bouge ? 6 : 4, Paint()..color = _couleur(id));
    // Le point sur objet se reconnaît, sans la couleur seule : un anneau.
    if (definition is PointSur) {
      canvas.drawCircle(p, 2.5, Paint()..color = fond);
    }
    if (figure.apparence(id).nomVisible) {
      _texte(canvas, figure.nom(id), p + const Offset(9, -24));
    }
  }

  void _etiquette(Canvas canvas, Size size, int id, FormeGeo forme) {
    final figure = atelier.figure;
    final apparence = figure.apparence(id);
    if (!apparence.nomVisible) return;
    if (forme is NombreGeo) {
      // Un curseur a sa barre ; une mesure se lit près de ce qu'elle mesure.
      final d = figure.definition(id);
      if (d is! Construite) return;
      final ancre = _ancreMesure(d, forme);
      if (ancre == null) return;
      final valeur = ecrireForme(forme, francais: francais);
      _texte(
        canvas,
        '${figure.nom(id)} = $valeur',
        vue.versEcran(ancre.x, ancre.y, size) + const Offset(6, 4),
        couleur: _couleur(id),
      );
      return;
    }
    // [AB] et (AB) se lisent déjà sur leurs points ; un polygone se voit.
    final d = figure.definition(id);
    if (forme is PolygoneGeo) return;
    if (d is Construite &&
        const {
          GenreConstruction.segment,
          GenreConstruction.droite,
          GenreConstruction.demiDroite,
          GenreConstruction.vecteur,
        }.contains(d.genre)) {
      return;
    }
    final ancre = _ancre(forme, size);
    if (ancre == null) return;
    _texte(canvas, figure.nom(id), ancre, couleur: _couleur(id));
  }

  Offset? _ancre(FormeGeo forme, Size size) {
    switch (forme) {
      case final DroiteGeo d:
        final centre = vue.versMaths(size.center(Offset.zero), size);
        final ecart = d.c - d.a * centre.x - d.b * centre.y;
        return vue.versEcran(
              centre.x + d.a * ecart + d.b * 60 / vue.unite,
              centre.y + d.b * ecart - d.a * 60 / vue.unite,
              size,
            ) +
            const Offset(6, 4);
      case final CercleGeo c:
        final angle = (c.depart ?? 1) + (c.balayage ?? 0) / 2;
        final p = c.point(angle);
        return vue.versEcran(p.x, p.y, size) + const Offset(6, -22);
      case final ConiqueGeo k:
        final p = k.point(k.plage.$1 + (k.plage.$2 - k.plage.$1) * 0.6);
        return vue.versEcran(p.x, p.y, size) + const Offset(6, -22);
      case final LieuGeo l:
        if (l.morceaux.isEmpty) return null;
        final m = l.morceaux.first;
        final p = m[m.length ~/ 2];
        return vue.versEcran(p.x, p.y, size) + const Offset(6, -22);
      case PointGeo() || PolygoneGeo() || NombreGeo():
        return null;
    }
  }

  /// Où écrire une mesure.
  PointGeo? _ancreMesure(Construite d, NombreGeo forme) {
    if (forme is AngleGeo) {
      final t = forme.depart + forme.balayage / 2;
      final r = 36 / vue.unite;
      return PointGeo(
        forme.sommet.x + r * math.cos(t),
        forme.sommet.y + r * math.sin(t),
      );
    }
    final formes = atelier.formes;
    final parent = formes[d.parents.first];
    return switch (parent) {
      final DroiteGeo droite when d.genre == GenreConstruction.longueur =>
        droite.estSegment
            ? PointGeo(
                (droite.debut!.x + droite.fin!.x) / 2,
                (droite.debut!.y + droite.fin!.y) / 2,
              )
            : null,
      final DroiteGeo droite => PointGeo(
        droite.a * droite.c + droite.b,
        droite.b * droite.c - droite.a,
      ),
      final PointGeo p => switch (formes[d.parents[1]]) {
        final PointGeo q => PointGeo((p.x + q.x) / 2, (p.y + q.y) / 2),
        _ => p,
      },
      final CercleGeo c => c.centre,
      final PolygoneGeo g => g.centre,
      final ConiqueGeo k => k.centre,
      _ => null,
    };
  }

  void _texte(Canvas canvas, String texte, Offset ou, {Color? couleur}) {
    TextPainter(
        text: TextSpan(
          text: texte,
          style: couleur == null
              ? this.texte
              : this.texte.copyWith(color: couleur),
        ),
        textDirection: TextDirection.ltr,
      )
      ..layout()
      ..paint(canvas, ou)
      ..dispose();
  }

  void _forme(
    Canvas canvas,
    Size size,
    FormeGeo forme,
    Paint peinture, {
    required bool pointille,
  }) {
    void tracer(Path chemin) =>
        canvas.drawPath(pointille ? _enPointille(chemin) : chemin, peinture);
    switch (forme) {
      case final DroiteGeo d:
        _droite(canvas, size, d, peinture, tracer);
      case final CercleGeo c:
        final centre = vue.versEcran(c.centre.x, c.centre.y, size);
        final rect = Rect.fromCircle(
          center: centre,
          radius: c.rayon * vue.unite,
        );
        final (depart, balayage) = (c.depart, c.balayage);
        tracer(
          depart == null || balayage == null
              ? (Path()..addOval(rect))
              : (Path()..addArc(rect, -depart, -balayage)),
        );
      case final PolygoneGeo g:
        final chemin = Path()
          ..addPolygon([
            for (final s in g.sommets) vue.versEcran(s.x, s.y, size),
          ], true);
        canvas.drawPath(
          chemin,
          Paint()..color = peinture.color.withValues(alpha: 0.12),
        );
        tracer(chemin);
      case final ConiqueGeo k:
        final centre = vue.versMaths(size.center(Offset.zero), size);
        final portee =
            k.centre.distance(PointGeo(centre.x, centre.y)) +
            size.longestSide / vue.unite;
        for (final morceau in k.traces(portee)) {
          tracer(_chemin(morceau, size));
        }
      case final LieuGeo l:
        for (final morceau in l.morceaux) {
          tracer(_chemin(morceau, size));
        }
      case final AngleGeo a:
        _angle(canvas, size, a, peinture);
      case PointGeo() || NombreGeo():
        break;
    }
  }

  Path _chemin(List<PointGeo> points, Size size) {
    final chemin = Path();
    for (final (i, p) in points.indexed) {
      final e = vue.versEcran(p.x, p.y, size);
      if (i == 0) {
        chemin.moveTo(e.dx, e.dy);
      } else {
        chemin.lineTo(e.dx, e.dy);
      }
    }
    return chemin;
  }

  void _angle(Canvas canvas, Size size, AngleGeo a, Paint peinture) {
    final s = vue.versEcran(a.sommet.x, a.sommet.y, size);
    const r = 20.0;
    final trait = Paint()
      ..color = peinture.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    // L'angle droit a sa marque carrée.
    if ((a.valeur - 90).abs() < 1e-6) {
      final (ux, uy) = (math.cos(-a.depart), math.sin(-a.depart));
      final (vx, vy) = (
        math.cos(-a.depart - math.pi / 2),
        math.sin(-a.depart - math.pi / 2),
      );
      const c = 14.0;
      canvas.drawPath(
        Path()
          ..moveTo(s.dx + c * ux, s.dy + c * uy)
          ..lineTo(s.dx + c * ux + c * vx, s.dy + c * uy + c * vy)
          ..lineTo(s.dx + c * vx, s.dy + c * vy),
        trait,
      );
      return;
    }
    final rect = Rect.fromCircle(center: s, radius: r);
    canvas
      ..drawArc(
        rect,
        -a.depart,
        -a.balayage,
        true,
        Paint()..color = peinture.color.withValues(alpha: 0.18),
      )
      ..drawArc(rect, -a.depart, -a.balayage, false, trait);
  }

  void _droite(
    Canvas canvas,
    Size size,
    DroiteGeo d,
    Paint peinture,
    void Function(Path) tracer,
  ) {
    final (debut, fin) = (d.debut, d.fin);
    final Offset a;
    final Offset b;
    // Une droite déborde de l'écran : deux points assez loin du centre.
    final centre = vue.versMaths(size.center(Offset.zero), size);
    final ecart = d.c - d.a * centre.x - d.b * centre.y;
    final portee =
        2 * math.max(size.width, size.height) / vue.unite + ecart.abs();
    if (debut != null && fin != null) {
      a = vue.versEcran(debut.x, debut.y, size);
      b = vue.versEcran(fin.x, fin.y, size);
    } else if (debut != null) {
      a = vue.versEcran(debut.x, debut.y, size);
      final loin = portee + PointGeo(centre.x, centre.y).distance(debut);
      b = vue.versEcran(debut.x + d.b * loin, debut.y - d.a * loin, size);
    } else {
      final (px, py) = (centre.x + d.a * ecart, centre.y + d.b * ecart);
      a = vue.versEcran(px + d.b * portee, py - d.a * portee, size);
      b = vue.versEcran(px - d.b * portee, py + d.a * portee, size);
    }
    tracer(
      Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy),
    );
    if (d.vecteur) {
      final angle = (b - a).direction;
      for (final ecartFleche in const [2.65, -2.65]) {
        canvas.drawLine(
          b,
          b + Offset.fromDirection(angle + ecartFleche, 12),
          peinture,
        );
      }
    }
  }

  Path _enPointille(Path chemin) {
    final resultat = Path();
    for (final mesure in chemin.computeMetrics()) {
      var position = 0.0;
      while (position < mesure.length) {
        resultat.addPath(
          mesure.extractPath(position, position + 8),
          Offset.zero,
        );
        position += 14;
      }
    }
    return resultat;
  }

  void _grille(Canvas canvas, Size size) {
    final fenetre = vue.fenetre(size);
    final pas = pasDeGraduation(vue.unite);
    final ligne = Paint()
      ..color = grille.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var k = (fenetre.xMin / pas).ceil(); k * pas <= fenetre.xMax; k++) {
      final x = vue.versEcran(k * pas, 0, size).dx;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), ligne);
    }
    for (var k = (fenetre.yMin / pas).ceil(); k * pas <= fenetre.yMax; k++) {
      final y = vue.versEcran(0, k * pas, size).dy;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), ligne);
    }
  }

  void _axes(Canvas canvas, Size size) {
    final fenetre = vue.fenetre(size);
    final pas = pasDeGraduation(vue.unite);
    final ligne = Paint()
      ..color = texte.color ?? grille
      ..strokeWidth = 1.2;
    final origine = vue.versEcran(0, 0, size);
    canvas
      ..drawLine(Offset(0, origine.dy), Offset(size.width, origine.dy), ligne)
      ..drawLine(Offset(origine.dx, 0), Offset(origine.dx, size.height), ligne);
    final petit = texte.copyWith(fontSize: 11, fontWeight: FontWeight.w400);
    void graduer(String t, Offset ou) {
      TextPainter(
          text: TextSpan(text: t, style: petit),
          textDirection: TextDirection.ltr,
        )
        ..layout()
        ..paint(canvas, ou)
        ..dispose();
    }

    for (var k = (fenetre.xMin / pas).ceil(); k * pas <= fenetre.xMax; k++) {
      if (k == 0) continue;
      final x = vue.versEcran(k * pas, 0, size).dx;
      canvas.drawLine(
        Offset(x, origine.dy - 3),
        Offset(x, origine.dy + 3),
        ligne,
      );
      graduer(
        texteGraduation(k * pas, pas, virgule: francais),
        Offset(x + 2, origine.dy + 3),
      );
    }
    for (var k = (fenetre.yMin / pas).ceil(); k * pas <= fenetre.yMax; k++) {
      if (k == 0) continue;
      final y = vue.versEcran(0, k * pas, size).dy;
      canvas.drawLine(
        Offset(origine.dx - 3, y),
        Offset(origine.dx + 3, y),
        ligne,
      );
      graduer(
        texteGraduation(k * pas, pas, virgule: francais),
        Offset(origine.dx + 5, y + 1),
      );
    }
  }

  @override
  bool shouldRepaint(PeintreFigure ancien) => true;
}
