import 'dart:math' as math;

import 'package:fikajiana/encre/formes.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tremblement déterministe : même résultat à chaque lancement.
Offset _bruit(int i, double amplitude) =>
    Offset(amplitude * math.sin(i * 1.7), amplitude * math.cos(i * 2.3));

List<Offset> _ligne(Offset a, Offset b, {double bruit = 1.5, int n = 40}) => [
  for (var i = 0; i <= n; i++) Offset.lerp(a, b, i / n)! + _bruit(i, bruit),
];

List<Offset> _cercle(double r, {double bruit = 2, int n = 60}) => [
  for (var i = 0; i <= n; i++)
    const Offset(300, 300) +
        Offset.fromDirection(2 * math.pi * i / n, r) +
        _bruit(i, bruit),
];

List<Offset> _polygone(List<Offset> sommets, {double bruit = 1.5}) => [
  for (var i = 0; i < sommets.length; i++)
    ..._ligne(
      sommets[i],
      sommets[(i + 1) % sommets.length],
      bruit: bruit,
      n: 25,
    ),
];

void main() {
  group('ligne', () {
    test('un trait droit tremblé devient une ligne', () {
      final forme = reconnaitreForme(
        _ligne(Offset.zero, const Offset(300, 200)),
      );
      expect(forme, isA<FormeLigne>());
    });

    test('presque horizontale : redressée', () {
      final forme =
          reconnaitreForme(_ligne(Offset.zero, const Offset(300, 12)))!
              as FormeLigne;
      expect(forme.b.dy, forme.a.dy);
    });

    test('presque verticale : redressée', () {
      final forme =
          reconnaitreForme(_ligne(Offset.zero, const Offset(10, 300)))!
              as FormeLigne;
      expect(forme.b.dx, forme.a.dx);
    });

    test('oblique : pas redressée', () {
      final forme =
          reconnaitreForme(_ligne(Offset.zero, const Offset(300, 200)))!
              as FormeLigne;
      expect(forme.b.dy, isNot(forme.a.dy));
    });
  });

  group('cercle', () {
    test('un cercle tremblé donne le bon centre et le bon rayon', () {
      final forme = reconnaitreForme(_cercle(100))! as FormeCercle;
      expect(forme.rayon, closeTo(100, 3));
      expect(forme.centre.dx, closeTo(300, 3));
      expect(forme.centre.dy, closeTo(300, 3));
    });

    test('un carré n’est pas un cercle', () {
      final forme = reconnaitreForme(
        _polygone(const [
          Offset.zero,
          Offset(200, 0),
          Offset(200, 200),
          Offset(0, 200),
          Offset.zero,
        ]),
      );
      expect(forme, isNot(isA<FormeCercle>()));
    });
  });

  group('polygones', () {
    test('triangle', () {
      final forme = reconnaitreForme(
        _polygone(const [
          Offset(100, 0),
          Offset(220, 200),
          Offset(0, 200),
          Offset(100, 0),
        ]),
      );
      expect(forme, isA<FormePolygone>());
      expect((forme! as FormePolygone).sommets, hasLength(3));
    });

    test('rectangle : aligné sur les axes', () {
      final forme = reconnaitreForme(
        _polygone(const [
          Offset.zero,
          Offset(300, 6),
          Offset(296, 200),
          Offset(2, 196),
          Offset.zero,
        ]),
      );
      final sommets = (forme! as FormePolygone).sommets;
      expect(sommets, hasLength(4));
      expect(sommets[0].dy, sommets[1].dy);
      expect(sommets[1].dx, sommets[2].dx);
    });
  });

  group('refus', () {
    test('trop peu de points ou trop court', () {
      expect(reconnaitreForme(const [Offset.zero, Offset(5, 5)]), isNull);
      expect(
        reconnaitreForme(_ligne(Offset.zero, const Offset(10, 5), bruit: 0)),
        isNull,
      );
    });

    test('un S ouvert n’est pas une forme', () {
      final s = [
        for (var i = 0; i <= 60; i++)
          Offset(100 * math.sin(i / 60 * 2 * math.pi), 3.0 * i),
      ];
      expect(reconnaitreForme(s), isNull);
    });

    test('un gribouillis fermé n’est pas une forme', () {
      final g = [
        for (var i = 0; i <= 80; i++)
          Offset(
            150 *
                math.sin(i / 80 * 2 * math.pi) *
                math.cos(i / 80 * 14 * math.pi),
            150 *
                math.cos(i / 80 * 2 * math.pi) *
                math.sin(i / 80 * 10 * math.pi),
          ),
      ];
      expect(reconnaitreForme(g), isNull);
    });
  });

  test('chaque forme donne des points pour la gomme et le rendu', () {
    expect(
      const FormeLigne(Offset.zero, Offset(60, 0)).echantillons().length,
      greaterThan(2),
    );
    expect(
      const FormeCercle(Offset.zero, 50).echantillons().length,
      greaterThan(20),
    );
  });
}
