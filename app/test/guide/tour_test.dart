import 'dart:math' as math;

import 'package:fikajiana/comprendre/ecriture_resultat.dart';
import 'package:fikajiana/guide/tour.dart';
import 'package:fikajiana/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final langue in ['fr', 'en']) {
    final etapes = etapesTour(lookupAppLocalizations(Locale(langue)));

    group('tour ($langue)', () {
      test('quelques étapes courtes, aux clés uniques', () {
        expect(etapes.length, inInclusiveRange(4, 10));
        final cles = etapes.map((e) => e.cle).toSet();
        expect(cles, hasLength(etapes.length));
      });

      test('chaque ligne et chaque résultat s’écrivent à la main', () {
        for (final etape in etapes) {
          expect(etape.titre.trim(), isNotEmpty);
          expect(etape.phrase.trim(), isNotEmpty);
          for (final (latex, resultat) in etape.lignes) {
            final ecrit = ecrireALEchelle(latex, 34);
            expect(ecrit, isNotNull, reason: latex);
            if (resultat != null) {
              expect(
                ecrireResultat(resultat, ecrit!.cadre),
                isNotNull,
                reason: resultat,
              );
            }
          }
        }
      });
    });
  }

  // Règle 8 : chaque résultat montré est recalculé ici, autrement.
  group('les résultats du tour sont justes', () {
    final etapes = {
      for (final e in etapesTour(lookupAppLocalizations(const Locale('fr'))))
        e.cle: e.lignes,
    };

    test('2+3×4 = 14 (la multiplication d’abord)', () {
      expect(etapes['calcul'], [(r'2+3\times4=', '14')]);
      expect(2 + 3 * 4, 14);
    });

    test('1/2 + 1/3 = 5/6 et √18 = 3√2', () {
      expect(etapes['exact']![0].$2, r'\frac{5}{6}');
      // 1/2 + 1/3 = (3 + 2)/6, déjà irréductible.
      expect(1 * 3 + 1 * 2, 5);
      expect(5.gcd(6), 1);
      expect(etapes['exact']![1].$2, r'3\sqrt{2}');
      expect(3 * 3 * 2, 18);
      expect(math.sqrt(18), closeTo(3 * math.sqrt(2), 1e-12));
    });

    test('x² − 5x + 6 = 0 a pour solutions 2 et 3, et seulement elles', () {
      expect(etapes['equation']![0].$2, contains('x=2'));
      expect(etapes['equation']![0].$2, contains('x=3'));
      double p(double x) => x * x - 5 * x + 6;
      expect(p(2), 0);
      expect(p(3), 0);
      // Le discriminant 25 − 24 = 1 > 0 : deux racines, pas plus.
      expect(25 - 24, 1);
    });

    test('f(x) = x² − 1 donne f(3) = 8', () {
      expect(etapes['fonction']![1], ('f(3)=', '8'));
      expect(3 * 3 - 1, 8);
    });

    test('det(1 2 ; 3 4) = 1×4 − 2×3 = −2', () {
      expect(etapes['matrices']![1], (r'\det(A)=', '-2'));
      expect(1 * 4 - 2 * 3, -2);
    });

    test('Σ k² de 1 à 10 = 385, et sin x / x tend vers 1 en 0', () {
      expect(etapes['sommes']![0].$2, '385');
      expect(
        [for (var k = 1; k <= 10; k++) k * k].reduce((a, b) => a + b),
        385,
      );
      // n(n+1)(2n+1)/6 pour n = 10.
      expect(10 * 11 * 21 ~/ 6, 385);
      expect(etapes['sommes']![1].$2, '1');
      for (final x in [1e-3, -1e-4, 1e-6]) {
        expect(math.sin(x) / x, closeTo(1, 1e-6));
      }
    });

    test('30 × 8 = 240', () {
      expect(etapes['juger'], [(r'30\times8=', '240')]);
      expect(30 * 8, 240);
    });

    test('5! = 120', () {
      expect(etapes['suite'], [('5!=', '120')]);
      expect([1, 2, 3, 4, 5].reduce((a, b) => a * b), 120);
    });
  });
}
