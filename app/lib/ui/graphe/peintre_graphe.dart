import 'dart:math' as math;

import 'package:fikajiana/graphe/courbes.dart';
import 'package:fikajiana/graphe/vue_graphe.dart';
import 'package:fikajiana/ui/formule_affichee.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Une courbe de la Figure : numéro et formule, à toucher pour la modifier.
class LegendeCourbe extends StatelessWidget {
  const new({
    required this.numero,
    required this.latex,
    required this.couleur,
    required this.surToucher,
    super.key,
  });

  final int numero;
  final String latex;
  final Color couleur;
  final VoidCallback surToucher;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: AppEspacement.sm),
      child: Material(
        elevation: 1,
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: surToucher,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppEspacement.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$numero',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: couleur,
                    ),
                  ),
                  const SizedBox(width: AppEspacement.sm),
                  Math.tex(
                    pourAffichage(latex),
                    textStyle: theme.textTheme.bodyMedium,
                    onErrorFallback: (_) => Text(latex),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Grille, axes, graduations, courbes numérotées et point lu.
class PeintreGraphe extends CustomPainter {
  const new({
    required this.vue,
    required this.courbes,
    required this.degres,
    required this.stylos,
    required this.fond,
    required this.axes,
    required this.grille,
    required this.texte,
    required this.virgule,
    this.point,
  });

  final VueGraphe vue;
  final List<Courbe> courbes;
  final bool degres;
  final List<Color> stylos;
  final Color fond;
  final Color axes;
  final Color grille;
  final TextStyle texte;
  final bool virgule;
  final ({int indice, double x, double y})? point;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..drawRect(Offset.zero & size, Paint()..color = fond)
      ..clipRect(Offset.zero & size);
    peindreSousLaFigure(canvas, size);
  }

  /// Grille graduée, axes et courbes : sous les objets de la Figure.
  void peindreSousLaFigure(Canvas canvas, Size size) {
    _grille(canvas, size);
    for (var i = 0; i < courbes.length; i++) {
      _courbe(canvas, size, i);
    }
    final point = this.point;
    if (point != null) _pointLu(canvas, size, point);
  }

  void _grille(Canvas canvas, Size size) {
    final fenetre = vue.fenetre(size);
    final pas = pasDeGraduation(vue.unite);
    final ligne = Paint()
      ..color = grille
      ..strokeWidth = 1;
    final origine = vue.versEcran(0, 0, size);
    // Hors de l'écran, les nombres restent lisibles le long du bord.
    final xAxe = origine.dx.clamp(4.0, size.width - 44);
    final yAxe = origine.dy.clamp(4.0, size.height - 20);

    final premierX = (fenetre.xMin / pas).ceil();
    for (var k = premierX; k * pas <= fenetre.xMax; k++) {
      final x = vue.versEcran(k * pas, 0, size).dx;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), ligne);
      if (k != 0) {
        _ecrire(
          canvas,
          texteGraduation(k * pas, pas, virgule: virgule),
          Offset(x + 3, yAxe + 2),
        );
      }
    }
    final premierY = (fenetre.yMin / pas).ceil();
    for (var k = premierY; k * pas <= fenetre.yMax; k++) {
      final y = vue.versEcran(0, k * pas, size).dy;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), ligne);
      if (k != 0) {
        _ecrire(
          canvas,
          texteGraduation(k * pas, pas, virgule: virgule),
          Offset(xAxe + 3, y + 2),
        );
      }
    }
    final axe = Paint()
      ..color = axes
      ..strokeWidth = 1.5;
    canvas
      ..drawLine(Offset(origine.dx, 0), Offset(origine.dx, size.height), axe)
      ..drawLine(Offset(0, origine.dy), Offset(size.width, origine.dy), axe);
  }

  void _courbe(Canvas canvas, Size size, int indice) {
    final couleur = stylos[indice % stylos.length];
    final trait = Paint()
      ..color = couleur
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final morceaux = courbes[indice].tracer(vue.fenetre(size), degres: degres);
    Offset? repere;
    // Un seul chemin : une courbe implicite compte des milliers de segments.
    final chemin = Path();
    for (final morceau in morceaux) {
      for (var i = 0; i < morceau.length; i++) {
        // Skia gère mal les coordonnées immenses des asymptotes.
        final p = vue.versEcran(morceau[i].x, morceau[i].y, size);
        final q = Offset(
          p.dx.clamp(-4000.0, size.width + 4000),
          p.dy.clamp(-4000.0, size.height + 4000),
        );
        if (i == 0) {
          chemin.moveTo(q.dx, q.dy);
        } else {
          chemin.lineTo(q.dx, q.dy);
        }
        final dansLaVue = q.dy >= 72 && q.dy <= size.height - 72;
        final etale = q.dx >= 0 && q.dx <= size.width - 40 - indice * 24;
        if (dansLaVue && etale) repere = q;
      }
    }
    canvas.drawPath(chemin, trait);
    // Chaque courbe porte son numéro, celui de la légende.
    final position = repere;
    if (position != null) {
      _ecrire(
        canvas,
        // Son nom s'il en a un (`C : …`), sinon son numéro.
        nomAffiche(courbes[indice].nom ?? '${indice + 1}'),
        position + const Offset(4, -22),
        style: texte.copyWith(color: couleur, fontWeight: FontWeight.bold),
      );
    }
  }

  void _pointLu(
    Canvas canvas,
    Size size,
    ({int indice, double x, double y}) point,
  ) {
    final p = vue.versEcran(point.x, point.y, size);
    canvas
      ..drawCircle(p, 6, Paint()..color = fond)
      ..drawCircle(p, 5, Paint()..color = stylos[point.indice % stylos.length]);
    final x = texteValeur(point.x, virgule: virgule);
    final y = texteValeur(point.y, virgule: virgule);
    final position = Offset(
      math.min(p.dx + 10, size.width - 140),
      math.max(p.dy - 28, 4),
    );
    _ecrire(canvas, '($x ; $y)', position, surFond: true);
  }

  void _ecrire(
    Canvas canvas,
    String contenu,
    Offset position, {
    TextStyle? style,
    bool surFond = false,
  }) {
    final peintre = TextPainter(
      text: TextSpan(text: contenu, style: style ?? texte),
      textDirection: TextDirection.ltr,
    )..layout();
    if (surFond) {
      canvas.drawRect(
        (position & peintre.size).inflate(3),
        Paint()..color = fond,
      );
    }
    peintre
      ..paint(canvas, position)
      ..dispose();
  }

  @override
  bool shouldRepaint(PeintreGraphe ancien) => true;
}
