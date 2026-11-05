import 'package:fikajiana/ui/theme/couleurs.dart';
import 'package:flutter/material.dart';

/// Le π tracé à la main sur sa tache, pour les états vides.
///
/// Décoratif : invisible pour le lecteur d'écran. Mêmes tracés que
/// `tool/generer_marque.py`, dans un repère de 108 unités.
class MarquePi extends StatelessWidget {
  const new({this.taille = 120, super.key});

  final double taille;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(taille),
        painter: const _PeintreMarque(),
      ),
    );
  }
}

class _PeintreMarque extends CustomPainter {
  const new();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 108);

    final tacheOrange = Path()
      ..moveTo(54, 25)
      ..cubicTo(63, 21, 74, 28, 77, 37)
      ..cubicTo(82, 41, 84, 50, 80, 57)
      ..cubicTo(84, 66, 77, 76, 67, 77)
      ..cubicTo(61, 84, 50, 84, 44, 79)
      ..cubicTo(35, 82, 26, 75, 27, 65)
      ..cubicTo(21, 58, 23, 47, 30, 42)
      ..cubicTo(30, 33, 44, 24, 54, 25)
      ..close();
    final tacheCiel = Path()
      ..moveTo(71, 57)
      ..cubicTo(76, 54, 83, 57, 84, 63)
      ..cubicTo(85, 69, 80, 74, 74, 73)
      ..cubicTo(69, 72, 66, 67, 67, 63)
      ..cubicTo(67, 60, 69, 58, 71, 57)
      ..close();
    canvas
      ..drawPath(tacheOrange, Paint()..color = AppCouleurs.orange)
      ..drawPath(tacheCiel, Paint()..color = AppCouleurs.ciel);

    for (final (couleur, x, y, r) in const [
      (AppCouleurs.ciel, 27.0, 37.0, 3.2),
      (AppCouleurs.ciel, 22.0, 49.0, 1.8),
      (AppCouleurs.saumon, 33.0, 79.0, 2.6),
      (AppCouleurs.saumon, 81.0, 37.0, 2.2),
      (AppCouleurs.ciel, 62.0, 23.0, 1.6),
    ]) {
      canvas.drawCircle(Offset(x, y), r, Paint()..color = couleur);
    }

    final trait = Paint()
      ..color = AppCouleurs.encre
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..drawPath(
        Path()
          ..moveTo(31, 45)
          ..cubicTo(37, 39, 45, 42, 54, 41)
          ..cubicTo(61, 40, 70, 41, 77, 37),
        trait,
      )
      ..drawPath(
        Path()
          ..moveTo(47, 42)
          ..cubicTo(47, 52, 45, 63, 37, 72),
        trait,
      )
      ..drawPath(
        Path()
          ..moveTo(63, 41)
          ..cubicTo(62, 51, 61, 60, 63, 67)
          ..cubicTo(64, 72, 70, 74, 75, 68),
        trait,
      );
  }

  @override
  bool shouldRepaint(_PeintreMarque ancien) => false;
}
