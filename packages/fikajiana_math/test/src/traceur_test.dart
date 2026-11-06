import 'dart:math' as math;

import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:test/test.dart';

const _fenetre = Fenetre(
  xMin: -10,
  xMax: 10,
  yMin: -10,
  yMax: 10,
  largeurPixels: 800,
  hauteurPixels: 800,
);

void main() {
  group('évaluer', () {
    // Valeurs de référence relevées avec Giac (commit 19a710a), 2026-11-06.
    const references = <(String, double, double)>[
      ('ln(5)', 0, 1.60943791243),
      ('sin(30)', 0, -0.988031624093),
      ('(x)^(2)+1', 3, 10),
      ('-(x)^(2)', 3, -9),
      ('(2)^(3)^(2)', 0, 512),
      ('(1)/(2)+(1)/(3)', 0, 0.833333333333),
      ('sqrt(x)', 2, 1.41421356237),
      ('abs(x-1)', -2, 3),
      ('exp(1)', 0, 2.71828182846),
      ('log10(1000)', 0, 3),
      ('tanh(1000)', 0, 1),
      ('cot(pi/4)', 0, 1),
      ('(e)^(x)', 1, 2.71828182846),
      ('2*x+3', 2, 7),
    ];
    for (final (entree, x, attendu) in references) {
      test(entree, () {
        expect(compilerFonction(entree)(x), closeTo(attendu, 1e-9));
      });
    }

    test('en degrés', () {
      expect(compilerFonction('sin(30)', degres: true)(0), closeTo(0.5, 1e-12));
      expect(compilerFonction('atan(1)', degres: true)(0), closeTo(45, 1e-12));
    });

    test('hors du domaine : NaN, jamais une valeur inventée', () {
      expect(compilerFonction('ln(x)')(-1).isNaN, isTrue);
      expect(compilerFonction('sqrt(x)')(-1).isNaN, isTrue);
    });

    for (final entree in ['y+1', 'solve(x=1,x)', '(', 'sin(', 'x+', 'x)']) {
      test('refuse $entree', () {
        expect(
          () => compilerFonction(entree),
          throwsA(isA<ErreurEvaluation>()),
        );
      });
    }
  });

  group('tracer', () {
    List<List<PointTrace>> tracer(String entree, [Fenetre f = _fenetre]) =>
        tracerFonction(compilerFonction(entree), f);

    test('une droite : un seul morceau, de bord à bord', () {
      final m = tracer('2*x+1');
      expect(m, hasLength(1));
      expect(m.single.first.x, -10);
      expect(m.single.last.x, 10);
    });

    test('sin : continue, et fidèle à moins d’un pixel', () {
      final m = tracer('sin(x)');
      expect(m, hasLength(1));
      final points = m.single;
      for (var i = 1; i < points.length; i++) {
        final (a, b) = (points[i - 1], points[i]);
        final milieu = (a.x + b.x) / 2;
        final corde = (a.y + b.y) / 2;
        // Une unité vaut 40 pixels.
        expect((math.sin(milieu) - corde).abs() * 40, lessThan(1));
      }
    });

    test('1/x : coupé à l’asymptote', () {
      final m = tracer('(1)/(x)');
      expect(m, hasLength(2));
      expect(m.first.last.x, lessThanOrEqualTo(0));
      expect(m.last.first.x, greaterThanOrEqualTo(0));
    });

    test('tan : un morceau par branche', () {
      // Sur [-10 ; 10], les asymptotes sont les π/2 + kπ : k de -4 à 2 et 3… 7.
      final asymptotes = [
        for (var k = -4; k <= 2; k++) math.pi / 2 + k * math.pi,
      ].where((a) => a > -10 && a < 10).length;
      expect(tracer('tan(x)'), hasLength(asymptotes + 1));
    });

    test('une courbe raide mais continue n’est pas coupée', () {
      expect(tracer('(x)^(3)'), hasLength(1));
      expect(tracer('exp(x)'), hasLength(1));
    });

    test('un saut est coupé, sans trait vertical', () {
      expect(tracer('abs(x)/x'), hasLength(2));
    });

    test('ln : commence au bord de son domaine', () {
      final m = tracer('ln(x)');
      expect(m, hasLength(1));
      expect(m.single.first.x, greaterThanOrEqualTo(0));
      expect(m.single.first.x, lessThan(0.1));
    });

    test('nulle part définie : rien', () {
      expect(tracer('sqrt(-1-(x)^(2))'), isEmpty);
    });

    test('reste léger', () {
      expect(tracer('sin(x)').single.length, lessThan(2000));
      final dense = tracer('sin((x)^(2))');
      expect(dense.expand((m) => m).length, lessThan(20000));
    });
  });
}
