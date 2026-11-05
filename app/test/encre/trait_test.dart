import 'dart:math' as math;

import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/encre/filtre_un_euro.dart';
import 'package:fikajiana/encre/formes.dart';
import 'package:flutter_test/flutter_test.dart';

PointEncre _p(double x, double y, [double t = 0]) =>
    PointEncre(x, y, 0.1, tempsMs: t);

void main() {
  group('filtre 1€', () {
    test('le premier point passe tel quel', () {
      expect(FiltreUnEuro().filtrer(const Offset(3, 4), 0), const Offset(3, 4));
    });

    test('lisse un tremblement autour d’un point fixe', () {
      final f = FiltreUnEuro();
      var maximum = 0.0;
      for (var i = 0; i < 100; i++) {
        final x = i.isEven ? 1.0 : -1.0;
        final sortie = f.filtrer(Offset(x, 0), i * 4.0);
        if (i > 20) maximum = math.max(maximum, sortie.dx.abs());
      }
      expect(maximum, lessThan(0.5));
    });

    test('suit un mouvement rapide de près', () {
      final f = FiltreUnEuro();
      var sortie = Offset.zero;
      for (var i = 0; i < 100; i++) {
        sortie = f.filtrer(Offset(i * 10.0, 0), i * 4.0);
      }
      expect(990 - sortie.dx, lessThan(40));
    });

    test('valeur calculée à la main, sur deux points', () {
      // dt = 0,1 s : dérivée 10, dérivée filtrée alpha(1 Hz) × 10, puis
      // coupure = 1 + 0,5 × |dérivée filtrée| et alpha(coupure).
      double alpha(double c) => 1 / (1 + 1 / (2 * math.pi * c) / 0.1);
      final derivee = alpha(1) * 10;
      final attendu = alpha(1 + 0.5 * derivee) * 1;
      final f = FiltreUnEuro(coupureMin: 1, beta: 0.5)..filtrer(Offset.zero, 0);
      expect(f.filtrer(const Offset(1, 0), 100).dx, closeTo(attendu, 1e-9));
    });
  });

  group('pression', () {
    test('la plage du stylet est étalée sur 0 à 1', () {
      expect(pressionNormalisee(0), 0);
      expect(pressionNormalisee(0.25), 1);
      expect(pressionNormalisee(1), 1);
      expect(pressionNormalisee(0.11), closeTo(0.66, 0.01));
    });
  });

  group('trait', () {
    test('les points bruts restent intacts pour la reconnaissance', () {
      final encre = Encre()..commencer(_p(0, 0));
      for (var i = 1; i < 20; i++) {
        encre.prolonger(_p(i * 5.0, i.isEven ? 3 : -3, i * 4.0));
      }
      final points = encre.traits.single.points;
      expect(points[1].position, const Offset(5, -3));
      expect(points[2].position, const Offset(10, 3));
      expect(encre.traits.single.contour.getBounds().isEmpty, isFalse);
    });

    test('former au maintien garde les points bruts et s’annule', () {
      final encre = Encre()..commencer(_p(0, 0));
      for (var i = 1; i <= 30; i++) {
        encre.prolonger(_p(i * 10.0, i.isEven ? 1 : -1, i * 4.0));
      }
      final brut = encre.traits.single.points.length;

      expect(encre.formerDernierTrait(), isTrue);
      expect(encre.traits.single.forme, isA<FormeLigne>());
      expect(encre.traits.single.points, hasLength(brut));

      encre.annuler();
      expect(encre.traits.single.forme, isNull);
      expect(encre.traits.single.points, hasLength(brut));
    });

    test('un trait quelconque ne devient pas une forme', () {
      final encre = Encre()..commencer(_p(0, 0));
      for (var i = 1; i <= 40; i++) {
        encre.prolonger(_p(100 * math.sin(i / 8), i * 5.0, i * 4.0));
      }
      expect(encre.formerDernierTrait(), isFalse);
      expect(encre.peutRefaire, isFalse);
    });

    test('après une forme, le stylet qui bouge encore ne change rien', () {
      final encre = Encre()..commencer(_p(0, 0));
      for (var i = 1; i <= 30; i++) {
        encre.prolonger(_p(i * 10.0, 0, i * 4.0));
      }
      encre
        ..formerDernierTrait()
        ..prolonger(_p(0, 500, 200));
      expect(encre.cadre!.bottom, 0);
    });

    test('la gomme touche la forme, pas les points bruts', () {
      final encre = Encre()..commencer(_p(0, 0));
      for (var i = 1; i <= 30; i++) {
        encre.prolonger(_p(i * 10.0, i.isEven ? 3 : -3, i * 4.0));
      }
      encre
        ..formerDernierTrait()
        ..gommer(const Offset(150, 1), 3);
      expect(encre.estVide, isTrue);
    });
  });
}
