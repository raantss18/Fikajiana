import 'dart:ui';

import 'package:fikajiana/export/capture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cadreDeLaPage', () {
    test('une page vide ne donne rien', () {
      expect(cadreDeLaPage(const []), isNull);
    });

    test('réunit les zones, avec une marge, sur des bords entiers', () {
      expect(
        cadreDeLaPage(const [
          Rect.fromLTRB(10.5, 20, 30, 40.2),
          Rect.fromLTRB(-5, 0, 3, 3),
        ], marge: 2),
        const Rect.fromLTRB(-7, -2, 32, 43),
      );
    });
  });

  group('tuilesDeLaPage', () {
    test('une petite zone tient en une tuile', () {
      const cadre = Rect.fromLTWH(10, 10, 50, 50);
      expect(tuilesDeLaPage(cadre, const Size(400, 800)), [cadre]);
    });

    test('couvre tout, sans trou ni recouvrement', () {
      const cadre = Rect.fromLTWH(-100, 50, 1000, 2000);
      // Une largeur d'écran fractionnaire tombe sur un pas entier.
      final tuiles = tuilesDeLaPage(cadre, const Size(411.4, 800));
      expect(tuiles, hasLength(3 * 3));
      expect(
        tuiles.fold<double>(0, (s, t) => s + t.width * t.height),
        cadre.width * cadre.height,
      );
      expect(tuiles.first.topLeft, cadre.topLeft);
      expect(tuiles.last.bottomRight, cadre.bottomRight);
      expect(tuiles[1].left, tuiles[0].right);
    });
  });

  group('echelleExport', () {
    test('plus fin que l’écran, sans dépasser le côté maximal', () {
      expect(echelleExport(400, 800), 3);
      expect(echelleExport(8192, 100), 0.5);
    });
  });
}
