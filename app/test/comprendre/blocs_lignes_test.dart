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

  group('un dénominateur écrit sous un calcul lu (téléphone d’Antsa)', () {
    const bloc = Rect.fromLTWH(0, 0, 300, 60);
    test('la barre et le 4 dessous le prolongent', () {
      trait(10, 80, 260, 2);
      trait(120, 100, 20, 50);
      expect(estDenominateur(bloc, encre.traits), isTrue);
    });
    test('la barre seule aussi, le dénominateur viendra', () {
      trait(10, 80, 260, 2);
      expect(estDenominateur(bloc, encre.traits), isTrue);
    });
    test('un moins court sur la ligne suivante, non', () {
      trait(0, 120, 30, 2);
      trait(50, 100, 30, 45);
      expect(estDenominateur(bloc, encre.traits), isFalse);
    });
    test('la ligne suivante, plus bas, non', () {
      trait(10, 160, 260, 2);
      expect(estDenominateur(bloc, encre.traits), isFalse);
    });
  });

  group('les bornes d’un grand signe (Pad 7 d’Antsa)', () {
    // Un bloc « lim » : le l est grand.
    const bloc = Rect.fromLTWH(0, 0, 120, 60);
    List<Trait> lim() {
      trait(0, 0, 4, 60);
      trait(20, 30, 0, 30);
      trait(40, 30, 40, 30);
      return encre.traits.toList();
    }

    test('x → 0 juste dessous va avec lim', () {
      final traitsDuBloc = lim();
      trait(0, 75, 20, 35);
      trait(30, 92, 40, 0);
      trait(80, 80, 20, 30);
      final groupe = encre.traits.skip(3).toList();
      expect(estBorne(bloc, traitsDuBloc, groupe), isTrue);
    });

    test('un 5 au-dessus aussi', () {
      final traitsDuBloc = lim();
      trait(0, -40, 20, 32);
      final groupe = encre.traits.skip(3).toList();
      expect(estBorne(bloc, traitsDuBloc, groupe), isTrue);
    });

    test('une ligne entière dessous, non', () {
      final traitsDuBloc = lim();
      trait(0, 80, 200, 40);
      final groupe = encre.traits.skip(3).toList();
      expect(estBorne(bloc, traitsDuBloc, groupe), isFalse);
    });

    test('trop loin dessous, non', () {
      final traitsDuBloc = lim();
      trait(0, 110, 20, 40);
      final groupe = encre.traits.skip(3).toList();
      expect(estBorne(bloc, traitsDuBloc, groupe), isFalse);
    });
  });
}
