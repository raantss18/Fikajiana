import 'dart:ui';

import 'package:fikajiana/comprendre/blocs.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Encre encre;
  setUp(() => encre = Encre());

  void trait(double x, double y, double l, double h) {
    encre.commencer(PointEncre(x, y, 0.1));
    for (var i = 1; i <= 8; i++) {
      encre.prolonger(PointEncre(x + l * i / 8, y + h * i / 8, 0.1));
    }
    encre.terminer();
  }

  /// Une ligne de cinq signes, avec un `g` dont la queue descend.
  void ligne(double y, {double queue = 0}) {
    trait(0, y, 30, 40 + queue); // g
    for (var i = 1; i <= 4; i++) {
      trait(50.0 * i, y, 30, 40);
    }
  }

  test('deux lignes serrées, même reliées par une queue, se séparent', () {
    ligne(0, queue: 45);
    ligne(70);
    final groupes = grouperTraits(encre.traits);
    expect(groupes, hasLength(2));
    expect(groupes.map((g) => g.length), everyElement(5));
  });

  test('une ligne avec son exposant reste une', () {
    ligne(0);
    trait(240, -30, 15, 15);
    expect(grouperTraits(encre.traits), hasLength(1));
  });

  test('une fraction reste entière', () {
    for (var i = 0; i < 3; i++) {
      trait(50.0 * i, 0, 30, 40);
    }
    trait(0, 55, 150, 2);
    for (var i = 0; i < 3; i++) {
      trait(50.0 * i, 70, 30, 40);
    }
    expect(grouperTraits(encre.traits), hasLength(1));
  });

  test('une matrice reste entière : ses parenthèses relient les lignes', () {
    trait(-30, -10, 5, 130);
    for (var i = 0; i < 3; i++) {
      trait(50.0 * i, 0, 30, 40);
      trait(50.0 * i, 60, 30, 40);
    }
    trait(160, -10, 5, 130);
    expect(grouperTraits(encre.traits), hasLength(1));
  });

  group('un groupe prolonge-t-il un bloc ?', () {
    const bloc = Rect.fromLTWH(0, 0, 300, 100);
    test('la ligne dessous, touchée par une queue, non', () {
      const dessous = Rect.fromLTWH(0, 80, 200, 80);
      expect(prolonge(bloc, dessous, ferme: false), isFalse);
    });
    test('un signe ajouté dans le bloc, oui', () {
      const signe = Rect.fromLTWH(100, 30, 30, 30);
      expect(prolonge(bloc, signe, ferme: true), isTrue);
    });
    test('à droite sur la même ligne, oui', () {
      const suite = Rect.fromLTWH(320, 20, 40, 40);
      expect(prolonge(bloc, suite, ferme: false), isTrue);
    });
  });
}
