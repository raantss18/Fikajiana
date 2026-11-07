import 'dart:math' as math;

import 'package:fikajiana/geometrie/atelier.dart';
import 'package:flutter/material.dart';

/// Le dessin d'un outil : ce qu'on touche en sombre, ce qu'on obtient en
/// couleur. Une parallèle se voit à sa droite d'origine et à son point.
class Pictogramme extends StatelessWidget {
  const new(this.outil, {this.taille = 32, super.key});

  final OutilGeo outil;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(taille),
        painter: _Peintre(outil, couleurs.onSurfaceVariant, couleurs.primary),
      ),
    );
  }
}

class _Peintre extends CustomPainter {
  const new(this.outil, this.donne, this.obtenu);

  final OutilGeo outil;
  final Color donne;
  final Color obtenu;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    _Trace(canvas, donne, obtenu).outil(outil);
  }

  @override
  bool shouldRepaint(_Peintre ancien) =>
      ancien.outil != outil || ancien.donne != donne || ancien.obtenu != obtenu;
}

class _Trace {
  const new(this.c, this.donne, this.obtenu);

  final Canvas c;
  final Color donne;
  final Color obtenu;

  Paint _trait(Color couleur, [double epaisseur = 1.7]) => Paint()
    ..color = couleur
    ..style = PaintingStyle.stroke
    ..strokeWidth = epaisseur
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void g(double x1, double y1, double x2, double y2) =>
      c.drawLine(Offset(x1, y1), Offset(x2, y2), _trait(donne, 1.3));
  void a(double x1, double y1, double x2, double y2) =>
      c.drawLine(Offset(x1, y1), Offset(x2, y2), _trait(obtenu, 2));
  void pg(double x, double y) =>
      c.drawCircle(Offset(x, y), 1.8, Paint()..color = donne);
  void pa(double x, double y) =>
      c.drawCircle(Offset(x, y), 2.4, Paint()..color = obtenu);
  void cg(double x, double y, double r) =>
      c.drawCircle(Offset(x, y), r, _trait(donne, 1.3));
  void ca(double x, double y, double r) =>
      c.drawCircle(Offset(x, y), r, _trait(obtenu, 2));

  /// Un arc, en degrés mathématiques : sens direct vers le haut.
  void arc(double x, double y, double r, double de, double sur) => c.drawArc(
    Rect.fromCircle(center: Offset(x, y), radius: r),
    -de * math.pi / 180,
    -sur * math.pi / 180,
    false,
    _trait(obtenu, 2),
  );

  void poly(List<Offset> s, Color couleur, {bool remplir = false}) {
    final chemin = Path()..addPolygon(s, true);
    if (remplir) {
      c.drawPath(chemin, Paint()..color = couleur.withValues(alpha: 0.28));
    }
    c.drawPath(chemin, _trait(couleur, couleur == obtenu ? 2 : 1.3));
  }

  void courbe(double Function(double) f, double de, double a2, Color couleur) {
    final chemin = Path()..moveTo(de, f(de));
    for (var x = de; x <= a2; x += 0.5) {
      chemin.lineTo(x, f(x));
    }
    c.drawPath(chemin, _trait(couleur, couleur == obtenu ? 2 : 1.3));
  }

  void fleche(double x1, double y1, double x2, double y2) {
    a(x1, y1, x2, y2);
    final angle = math.atan2(y2 - y1, x2 - x1);
    for (final d in const [2.6, -2.6]) {
      a(
        x2,
        y2,
        x2 - 4.5 * math.cos(angle + d * 0.2),
        y2 - 4.5 * math.sin(angle + d * 0.2),
      );
    }
  }

  void outil(OutilGeo outil) {
    switch (outil) {
      case OutilGeo.deplacer:
        fleche(12, 12, 12, 3);
        fleche(12, 12, 12, 21);
        fleche(12, 12, 3, 12);
        fleche(12, 12, 21, 12);
      case OutilGeo.gomme:
        g(3, 21, 21, 3);
        a(6, 6, 18, 18);
        a(18, 6, 6, 18);
      case OutilGeo.mainLevee:
        // Un trait qui ondule, et le segment net qu'il devient.
        a(3, 16, 7, 11);
        a(7, 11, 11, 15);
        a(11, 15, 15, 9);
        a(15, 9, 21, 13);
        g(3, 21, 21, 19);
      case OutilGeo.point:
        pa(12, 12);
      case OutilGeo.milieu:
        g(3, 19, 21, 5);
        pg(3, 19);
        pg(21, 5);
        pa(12, 12);
      case OutilGeo.intersection:
        g(3, 3, 21, 21);
        g(3, 21, 21, 3);
        pa(12, 12);
      case OutilGeo.centre:
        cg(12, 12, 9);
        pa(12, 12);
      case OutilGeo.centreGravite:
        poly(const [Offset(3, 20), Offset(21, 20), Offset(12, 4)], donne);
        pa(12, 14.7);
      case OutilGeo.segment:
        a(5, 18, 19, 6);
        pg(5, 18);
        pg(19, 6);
      case OutilGeo.droite:
        a(1, 21, 23, 3);
        pg(8, 15.3);
        pg(16, 8.7);
      case OutilGeo.demiDroite:
        a(4, 19, 23, 4);
        pg(4, 19);
        pg(13, 12);
      case OutilGeo.vecteur:
        fleche(4, 19, 20, 5);
        pg(4, 19);
      case OutilGeo.parallele:
        g(2, 16, 16, 2);
        a(8, 22, 22, 8);
        pg(15, 15);
      case OutilGeo.perpendiculaire:
        g(2, 19, 22, 19);
        a(12, 2, 12, 19);
        g(12, 15, 16, 15);
        g(16, 15, 16, 19);
        pg(12, 7);
      case OutilGeo.mediatrice:
        g(3, 14, 21, 14);
        pg(3, 14);
        pg(21, 14);
        a(12, 2, 12, 22);
        g(7.5, 12.5, 7.5, 15.5);
        g(16.5, 12.5, 16.5, 15.5);
      case OutilGeo.bissectrice:
        g(3, 20, 22, 20);
        g(3, 20, 15, 4);
        a(3, 20, 22, 9.5);
        pg(3, 20);
      case OutilGeo.tangente:
        cg(11, 14, 7);
        a(1, 7, 23, 7);
        pa(11, 7);
      case OutilGeo.cercle:
        ca(12, 12, 8.5);
        pg(12, 12);
        pg(20.5, 12);
      case OutilGeo.cercleRayon:
        ca(12, 12, 8.5);
        pg(12, 12);
        g(12, 12, 18, 6);
      case OutilGeo.cercleTroisPoints:
        ca(12, 12, 8.5);
        pg(12, 3.5);
        pg(4.6, 16.2);
        pg(19.4, 16.2);
      case OutilGeo.arc:
        arc(6, 18, 14, 0, 90);
        g(6, 18, 20, 18);
        g(6, 18, 6, 4);
        pg(6, 18);
        pg(20, 18);
        pg(6, 4);
      case OutilGeo.arcTroisPoints:
        arc(12, 16, 9, 0, 180);
        pg(3, 16);
        pg(12, 7);
        pg(21, 16);
      case OutilGeo.demiCercle:
        arc(12, 17, 9, 0, 180);
        g(3, 17, 21, 17);
        pg(3, 17);
        pg(21, 17);
      case OutilGeo.polygone:
        poly(
          const [Offset(4, 18), Offset(9, 4), Offset(20, 7), Offset(19, 20)],
          obtenu,
          remplir: true,
        );
        pg(4, 18);
        pg(9, 4);
        pg(20, 7);
        pg(19, 20);
      case OutilGeo.polygoneRegulier:
        poly(
          [
            for (var i = 0; i < 6; i++)
              Offset(
                12 + 9 * math.cos(i * math.pi / 3),
                12 + 9 * math.sin(i * math.pi / 3),
              ),
          ],
          obtenu,
          remplir: true,
        );
      case OutilGeo.ellipse:
        c.drawOval(const Rect.fromLTRB(2, 6, 22, 18), _trait(obtenu, 2));
        pg(7, 12);
        pg(17, 12);
      case OutilGeo.hyperbole:
        courbe(
          (x) => 12 + 1.2 * math.sqrt(math.pow(x - 12, 2) - 9),
          15.2,
          22,
          obtenu,
        );
        courbe(
          (x) => 12 - 1.2 * math.sqrt(math.pow(x - 12, 2) - 9),
          15.2,
          22,
          obtenu,
        );
        courbe(
          (x) => 12 + 1.2 * math.sqrt(math.pow(12 - x, 2) - 9),
          2,
          8.8,
          obtenu,
        );
        courbe(
          (x) => 12 - 1.2 * math.sqrt(math.pow(12 - x, 2) - 9),
          2,
          8.8,
          obtenu,
        );
        pg(7, 12);
        pg(17, 12);
      case OutilGeo.parabole:
        courbe((x) => 3 + (x - 12) * (x - 12) * 0.2, 3, 21, obtenu);
        g(2, 21, 22, 21);
        pg(12, 7);
      case OutilGeo.coniqueCinqPoints:
        c.drawOval(const Rect.fromLTRB(2, 6, 22, 18), _trait(obtenu, 2));
        pg(2, 12);
        pg(22, 12);
        pg(12, 6);
        pg(12, 18);
        pg(5, 8);
      case OutilGeo.symetrieCentrale:
        poly(const [Offset(2, 21), Offset(9, 21), Offset(5, 15)], donne);
        poly(const [Offset(22, 3), Offset(15, 3), Offset(19, 9)], obtenu);
        pg(12, 12);
      case OutilGeo.symetrieAxiale:
        g(12, 2, 12, 22);
        poly(const [Offset(3, 18), Offset(9, 18), Offset(9, 7)], donne);
        poly(const [Offset(21, 18), Offset(15, 18), Offset(15, 7)], obtenu);
      case OutilGeo.translation:
        poly(const [Offset(2, 22), Offset(8, 22), Offset(3, 16)], donne);
        poly(const [Offset(16, 10), Offset(22, 10), Offset(17, 4)], obtenu);
        fleche(7, 14, 14, 9);
      case OutilGeo.rotation:
        poly(const [Offset(13, 21), Offset(20, 21), Offset(20, 15)], donne);
        poly(const [Offset(3, 11), Offset(3, 4), Offset(9, 4)], obtenu);
        pg(12, 12);
        arc(12, 12, 6, 0, 120);
      case OutilGeo.homothetie:
        g(2, 21, 21, 3);
        g(2, 21, 22, 21);
        poly(const [Offset(2, 21), Offset(9, 21), Offset(9, 14.3)], donne);
        poly(const [Offset(2, 21), Offset(21, 21), Offset(21, 3)], obtenu);
        pg(2, 21);
      case OutilGeo.longueur:
        a(3, 15, 21, 15);
        a(3, 12, 3, 18);
        a(21, 12, 21, 18);
        g(9, 15, 9, 12.5);
        g(15, 15, 15, 12.5);
        g(12, 15, 12, 11);
      case OutilGeo.angle:
        g(3, 20, 22, 20);
        g(3, 20, 18, 5);
        arc(3, 20, 11, 0, 45);
        pg(3, 20);
      case OutilGeo.aire:
        poly(
          const [Offset(3, 20), Offset(21, 20), Offset(21, 5)],
          obtenu,
          remplir: true,
        );
      case OutilGeo.pente:
        a(3, 19, 20, 6);
        g(3, 19, 20, 19);
        g(20, 19, 20, 6);
      case OutilGeo.curseur:
        g(2, 12, 22, 12);
        c.drawCircle(const Offset(15, 12), 4, Paint()..color = obtenu);
      case OutilGeo.lieu:
        for (var i = 0; i < 12; i++) {
          final t = i * math.pi / 6;
          c.drawCircle(
            Offset(12 + 9 * math.cos(t), 12 + 6 * math.sin(t)),
            1.1,
            Paint()..color = obtenu,
          );
        }
        pg(12, 12);
      case OutilGeo.relation:
        g(2, 14, 12, 4);
        g(12, 22, 22, 12);
        TextPainter(
            text: TextSpan(
              text: '?',
              style: TextStyle(
                color: obtenu,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            textDirection: TextDirection.ltr,
          )
          ..layout()
          ..paint(c, const Offset(9, 5))
          ..dispose();
    }
  }
}
