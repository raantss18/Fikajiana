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

  group('deux variables', () {
    // Valeurs relevées avec SymPy 1.14, 2026-11-06.
    test('évaluer', () {
      final f = compilerFonctionXY('(x)^(3)+(y)^(3)-3*x*y');
      expect(f(1.5, 1.5), closeTo(0, 1e-12));
      expect(compilerFonctionXY('x+y')(2, 3), 5);
    });

    test('une autre lettre reste refusée', () {
      expect(() => compilerFonctionXY('x+z'), throwsA(isA<ErreurEvaluation>()));
    });

    test('compilerFonction refuse toujours y', () {
      expect(() => compilerFonction('y'), throwsA(isA<ErreurEvaluation>()));
    });
  });

  group('courbes implicites', () {
    List<List<PointTrace>> tracer(String giac) =>
        tracerImplicite(compilerFonctionXY(giac), _fenetre);

    void verifier(
      List<List<PointTrace>> m,
      double Function(double, double) distance,
    ) {
      expect(m, isNotEmpty);
      for (final segment in m) {
        for (final p in segment) {
          // Un pixel vaut 1/40 d'unité.
          expect(distance(p.x, p.y).abs() * 40, lessThan(1), reason: '$p');
        }
      }
    }

    test('cercle x²+y²=16 : sur le cercle, et sa longueur', () {
      final m = tracer('(x)^(2)+(y)^(2)-(16)');
      verifier(m, (x, y) => math.sqrt(x * x + y * y) - 4);
      var longueur = 0.0;
      for (final s in m) {
        longueur += math.sqrt(
          math.pow(s[1].x - s[0].x, 2) + math.pow(s[1].y - s[0].y, 2),
        );
      }
      expect(longueur, closeTo(2 * math.pi * 4, 0.05));
    });

    test('droite verticale x=3', () {
      verifier(tracer('x-(3)'), (x, _) => x - 3);
    });

    test('hyperbole xy=1 : deux branches, rien entre elles', () {
      final m = tracer('x*y-(1)');
      verifier(m, (x, y) => (x * y - 1) / math.sqrt(x * x + y * y));
      for (final s in m) {
        expect(s[0].x.sign, s[1].x.sign);
      }
    });

    test('folium x³+y³=3xy passe par (3/2 ; 3/2)', () {
      final m = tracer('(x)^(3)+(y)^(3)-3*x*y');
      final proche = m
          .expand((s) => s)
          .map((p) {
            return math.sqrt(math.pow(p.x - 1.5, 2) + math.pow(p.y - 1.5, 2));
          })
          .reduce(math.min);
      expect(proche, lessThan(0.05));
    });

    test('un pôle n’est pas une courbe : y=1/x sans trait vertical', () {
      final m = tracer('y-(1)/(x)');
      for (final s in m) {
        expect(s[0].x * s[1].x, greaterThan(0), reason: '$s');
      }
    });

    test('une courbe bornée par son domaine', () {
      // y = sqrt(x) sur x positif seulement.
      final m = tracer('y-sqrt(x)');
      expect(m, isNotEmpty);
      for (final s in m) {
        expect(s[0].x, greaterThanOrEqualTo(0));
      }
    });

    test('vide : x²+y²=-1 ne trace rien', () {
      expect(tracer('(x)^(2)+(y)^(2)+1'), isEmpty);
    });

    test('reste léger', () {
      // Des dizaines d'hyperboles xy = kπ sur 20 × 20 unités : le pire cas.
      expect(tracer('sin(x*y)').expand((s) => s).length, lessThan(60000));
    });
  });

  group('courbes paramétrées', () {
    List<List<PointTrace>> tracer(
      String x,
      String y,
      double debut,
      double fin,
    ) => tracerParametree(
      compilerFonction(x, variable: 't'),
      compilerFonction(y, variable: 't'),
      debut,
      fin,
      _fenetre,
    );

    double longueur(List<PointTrace> m) {
      var l = 0.0;
      for (var i = 1; i < m.length; i++) {
        l += math.sqrt(
          math.pow(m[i].x - m[i - 1].x, 2) + math.pow(m[i].y - m[i - 1].y, 2),
        );
      }
      return l;
    }

    test('cercle de rayon 2 : longueur 4π', () {
      final m = tracer('2*cos(t)', '2*sin(t)', 0, 2 * math.pi);
      expect(m, hasLength(1));
      expect(longueur(m.single), closeTo(12.5663706143592, 0.01));
    });

    test('cycloïde : longueur 8 sur une arche', () {
      final m = tracer('t-sin(t)', '1-cos(t)', 0, 2 * math.pi);
      expect(longueur(m.single), closeTo(8, 0.01));
    });

    test('Lissajous en t=1 : (sin 3 ; cos 2) d’après SymPy', () {
      final m = tracer('sin(3*t)', 'cos(2*t)', 0, 1);
      expect(m.single.last.x, closeTo(0.141120008059867, 1e-9));
      expect(m.single.last.y, closeTo(-0.416146836547142, 1e-9));
    });

    test('hors du domaine : coupée, pas reliée', () {
      final m = tracer('t', 'sqrt(t)', -2, 2);
      expect(m, hasLength(1));
      expect(m.single.first.x, greaterThanOrEqualTo(0));
    });

    test('un saut est coupé', () {
      final m = tracer('t', '(1)/(t)', -2, 2);
      expect(m, hasLength(2));
    });

    test('loin de l’écran : rien de relié à travers', () {
      final m = tracer('t+100', 't', -1, 1);
      expect(m, isEmpty);
    });
  });
}
