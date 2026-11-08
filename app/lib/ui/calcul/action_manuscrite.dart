import 'dart:math' as math;

import 'package:fikajiana/comprendre/ecriture_resultat.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:flutter/material.dart';

/// Une action de la Feuille écrite à la main, comme les résultats : `tracer`
/// souligné d'un trait, et non une pastille imprimée (Antsa, Pad 7).
///
/// [mot] s'écrit avec l'alphabet manuscrit des résultats (lettres sans
/// accent) ; [libelle] est ce que dit TalkBack, en entier. La cible fait au
/// moins 48 dp (règle 9).
class ActionManuscrite extends StatelessWidget {
  const new({
    required this.mot,
    required this.libelle,
    required this.surToucher,
    super.key,
  });

  final String mot;
  final String libelle;
  final VoidCallback surToucher;

  /// La hauteur d'écriture, proche de celle des résultats courts.
  static const double _hauteur = 30;

  @override
  Widget build(BuildContext context) {
    final couleur = Theme.of(context).colorScheme.tertiary;
    final ecrit = ecrireResultat(
      '\\mathrm{$mot}',
      const Rect.fromLTWH(0, 0, 0, _hauteur),
    );
    return Semantics(
      button: true,
      label: libelle,
      excludeSemantics: true,
      child: Tooltip(
        message: libelle,
        child: InkWell(
          onTap: surToucher,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppEspacement.sm),
              child: Center(
                widthFactor: 1,
                child: ecrit == null
                    // Un mot sans lettres manuscrites : le texte, par défaut.
                    ? Text(
                        mot,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: couleur),
                      )
                    : CustomPaint(
                        size: Size(ecrit.cadre.width, ecrit.cadre.height + 8),
                        painter: _PeintreMot(ecrit, couleur),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PeintreMot extends CustomPainter {
  const new(this.ecrit, this.couleur);

  final EcritureResultat ecrit;
  final Color couleur;

  @override
  void paint(Canvas canvas, Size size) {
    final encre = Paint()..color = couleur;
    canvas
      ..save()
      ..translate(-ecrit.cadre.left, -ecrit.cadre.top);
    for (final contour in ecrit.contours) {
      canvas.drawPath(contour, encre);
    }
    canvas.restore();
    // Le trait qui souligne : ce mot se touche, comme un lien écrit.
    final y = size.height - 3;
    final trait = Path()..moveTo(0, y);
    for (var x = 0.0; x <= size.width; x += 4) {
      trait.lineTo(x, y + math.sin(x / 9) * 1.2);
    }
    canvas.drawPath(
      trait,
      Paint()
        ..color = couleur
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_PeintreMot ancien) =>
      ancien.ecrit != ecrit || ancien.couleur != couleur;
}

/// Le petit crayon, tracé à la main : corriger ce qui a été lu.
class CrayonManuscrit extends StatelessWidget {
  const new({required this.libelle, required this.surToucher, super.key});

  final String libelle;
  final VoidCallback surToucher;

  @override
  Widget build(BuildContext context) {
    final couleur = Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      button: true,
      label: libelle,
      excludeSemantics: true,
      child: Tooltip(
        message: libelle,
        child: InkWell(
          onTap: surToucher,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: 48,
            child: CustomPaint(painter: _PeintreCrayon(couleur)),
          ),
        ),
      ),
    );
  }
}

class _PeintreCrayon extends CustomPainter {
  const new(this.couleur);

  final Color couleur;

  @override
  void paint(Canvas canvas, Size size) {
    final trait = Paint()
      ..color = couleur
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Un crayon penché, dessiné d'un geste : corps, pointe, mine.
    final c = size.center(Offset.zero);
    Offset p(double x, double y) => c + Offset(x, y);
    canvas
      ..drawPath(
        Path()
          ..moveTo(p(7, -11).dx, p(7, -11).dy)
          ..lineTo(p(11, -7).dx, p(11, -7).dy)
          ..lineTo(p(-5, 9.2).dx, p(-5, 9.2).dy)
          ..lineTo(p(-10, 10.5).dx, p(-10, 10.5).dy)
          ..lineTo(p(-8.8, 5.2).dx, p(-8.8, 5.2).dy)
          ..close(),
        trait,
      )
      ..drawLine(p(4, -8), p(8, -4), trait)
      ..drawLine(p(-8.8, 5.2), p(-5, 9.2), trait);
  }

  @override
  bool shouldRepaint(_PeintreCrayon ancien) => ancien.couleur != couleur;
}

/// Une formule écrite à la main, comme les résultats : une ligne tapée au
/// clavier s'écrit elle aussi à la main sur la Feuille (Antsa). Ce que la
/// main ne sait pas écrire garde [repli].
class EcritureManuscrite extends StatelessWidget {
  const new({
    required this.latex,
    required this.couleur,
    required this.repli,
    this.hauteur = 36,
    super.key,
  });

  final String latex;
  final Color couleur;
  final Widget repli;

  /// La hauteur d'écriture, proche de celle d'une ligne écrite au stylet.
  final double hauteur;

  @override
  Widget build(BuildContext context) {
    final ecrit = ecrireResultat(latex, Rect.fromLTWH(0, 0, 0, hauteur));
    if (ecrit == null) return repli;
    return Semantics(
      label: latex,
      child: CustomPaint(
        size: ecrit.cadre.size,
        painter: _PeintreEcriture(ecrit, couleur),
      ),
    );
  }
}

class _PeintreEcriture extends CustomPainter {
  const new(this.ecrit, this.couleur);

  final EcritureResultat ecrit;
  final Color couleur;

  @override
  void paint(Canvas canvas, Size size) {
    final encre = Paint()..color = couleur;
    canvas.translate(-ecrit.cadre.left, -ecrit.cadre.top);
    for (final contour in ecrit.contours) {
      canvas.drawPath(contour, encre);
    }
  }

  @override
  bool shouldRepaint(_PeintreEcriture ancien) =>
      ancien.ecrit != ecrit || ancien.couleur != couleur;
}

/// Une autre lecture possible, écrite à la main : la toucher la choisit.
/// TalkBack dit [libelle] ; la cible fait au moins 48 dp (règle 9).
class LectureManuscrite extends StatelessWidget {
  const new({
    required this.latex,
    required this.couleur,
    required this.libelle,
    required this.surToucher,
    super.key,
  });

  final String latex;
  final Color couleur;
  final String libelle;
  final VoidCallback surToucher;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: libelle,
      excludeSemantics: true,
      child: Tooltip(
        message: libelle,
        child: InkWell(
          onTap: surToucher,
          borderRadius: BorderRadius.circular(AppEspacement.sm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppEspacement.sm),
              child: Center(
                widthFactor: 1,
                child: EcritureManuscrite(
                  latex: latex,
                  couleur: couleur,
                  hauteur: 28,
                  repli: Text(latex, style: TextStyle(color: couleur)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
