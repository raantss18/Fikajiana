import 'dart:ui';

import 'package:fikajiana/ui/calcul/ecran_feuille.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('une feuille vide : la ligne tapée se pose au départ', () {
    const depart = Offset(100, 100);
    expect(placeLibre(depart, const []), depart);
  });

  test('l’écriture est là : la ligne tapée descend sous elle', () {
    // Vu sur le Pad 7 : `développer(…)` posé sur `f'(x)=e^x`.
    const ecriture = [
      Rect.fromLTWH(80, 60, 600, 100),
      Rect.fromLTWH(80, 180, 600, 100),
    ];
    final p = placeLibre(const Offset(100, 100), ecriture);
    final occupe = Rect.fromLTWH(p.dx, p.dy - 32, 480, 64);
    expect(ecriture.any(occupe.overlaps), isFalse);
    expect(p.dy, greaterThan(280));
  });

  test('un trou assez grand entre deux lignes est pris', () {
    const ecriture = [
      Rect.fromLTWH(80, 60, 600, 60),
      Rect.fromLTWH(80, 400, 600, 60),
    ];
    final p = placeLibre(const Offset(100, 100), ecriture);
    expect(p.dy, lessThan(400));
  });
}
