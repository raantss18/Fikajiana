import 'dart:math' as math;

import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/encre/feuille_encre.dart';
import 'package:fikajiana/encre/rature.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un va-et-vient de [passes] traits dans un rectangle.
List<Offset> zigzag(int passes, {double l = 60, double h = 30}) {
  final p = <Offset>[];
  for (var k = 0; k < passes; k++) {
    final (a, b) = k.isEven ? (0.0, l) : (l, 0.0);
    final y = h * k / passes;
    for (var i = 0; i <= 12; i++) {
      p.add(Offset(a + (b - a) * i / 12, y));
    }
  }
  return p;
}

List<Offset> courbe(double Function(double) x, double Function(double) y) => [
  for (var i = 0; i <= 80; i++) Offset(x(i / 80), y(i / 80)),
];

void main() {
  group('reconnaître une rature', () {
    test('un va-et-vient, au doigt ou serré', () {
      expect(estRature(zigzag(6)), isTrue);
      expect(estRature(zigzag(8, l: 20, h: 16)), isTrue);
      expect(estRature(zigzag(5, l: 120, h: 12)), isTrue);
    });

    test('un tournoiement', () {
      final spirale = courbe(
        (t) => 40 + 25 * math.cos(t * 8 * math.pi),
        (t) => 40 + 25 * math.sin(t * 8 * math.pi),
      );
      expect(estRature(spirale), isTrue);
    });

    // Ce qu'on écrit tous les jours ne doit jamais effacer.
    final ecritures = <String, List<Offset>>{
      'droite': courbe((t) => 60 * t, (t) => 20 * t),
      '1': [
        Offset.zero,
        const Offset(10, -6),
        for (var i = 0; i < 40; i++) Offset(10, -6 + i * 2.0),
      ],
      'cercle, 0': courbe(
        (t) => 30 * math.cos(t * 2 * math.pi),
        (t) => 40 * math.sin(t * 2 * math.pi),
      ),
      '8': courbe(
        (t) => 20 * math.sin(t * 4 * math.pi),
        (t) => 40 * math.sin(t * 2 * math.pi),
      ),
      'm': [
        for (final (a, b) in const [
          (Offset(0, 40), Offset(5, 0)),
          (Offset(5, 0), Offset(15, 40)),
          (Offset(15, 40), Offset(25, 0)),
          (Offset(25, 0), Offset(35, 40)),
        ])
          for (var i = 0; i <= 10; i++) Offset.lerp(a, b, i / 10)!,
      ],
      'w': [
        for (final (a, b) in const [
          (Offset.zero, Offset(10, 40)),
          (Offset(10, 40), Offset(20, 5)),
          (Offset(20, 5), Offset(30, 40)),
          (Offset(30, 40), Offset(40, 0)),
        ])
          for (var i = 0; i <= 10; i++) Offset.lerp(a, b, i / 10)!,
      ],
      'sinusoïde longue': courbe(
        (t) => 200 * t,
        (t) => 20 * math.sin(t * 6 * math.pi),
      ),
      'tout petit': [for (var i = 0; i < 40; i++) Offset(i % 2 * 5.0, i * 0.1)],
      'un point': const [Offset.zero],
    };
    for (final MapEntry(key: nom, value: points) in ecritures.entries) {
      test("n'efface pas : $nom", () {
        expect(estRature(points), isFalse);
      });
    }
  });

  group('sur la feuille', () {
    void tracer(Encre e, List<Offset> points, {Offset en = Offset.zero}) {
      e.commencer(
        PointEncre(points.first.dx + en.dx, points.first.dy + en.dy, 1),
      );
      for (final p in points.skip(1)) {
        e.prolonger(PointEncre(p.dx + en.dx, p.dy + en.dy, 1));
      }
      e.terminer();
    }

    final chiffre = courbe((t) => 20 + 10 * t, (t) => 5 + 20 * t);
    final ailleurs = courbe((t) => 300 + 10 * t, (t) => 5 + 20 * t);

    test('la rature emporte ce qu’elle couvre, et elle-même', () {
      final e = Encre();
      tracer(e, chiffre);
      tracer(e, ailleurs);
      tracer(e, zigzag(6));
      final r = e.raturerDernierTrait()!;
      expect(r.emportes, hasLength(1));
      expect(e.traits, hasLength(1));
      expect(e.traits.single.points.first.x, 300);
    });

    test('une seule annulation remet tout', () {
      final e = Encre();
      tracer(e, chiffre);
      tracer(e, zigzag(6));
      e
        ..raturerDernierTrait()
        ..annuler();
      expect(e.traits, hasLength(1));
      expect(e.traits.single.points.first.x, 20);
    });

    test('sur rien : le trait reste, c’était peut-être de l’écriture', () {
      final e = Encre();
      tracer(e, ailleurs);
      tracer(e, zigzag(6));
      expect(e.raturerDernierTrait(), isNull);
      expect(e.traits, hasLength(2));
    });

    test('un trait à peine effleuré reste', () {
      final e = Encre();
      tracer(e, courbe((t) => 50 + 300 * t, (t) => 15));
      tracer(e, zigzag(6));
      expect(e.raturerDernierTrait(), isNull);
    });

    test('les cibles en plus partent aussi', () {
      final e = Encre();
      tracer(e, ailleurs);
      final id = e.traits.single.id;
      tracer(e, zigzag(6));
      final r = e.raturerDernierTrait(enPlus: (_) => {id})!;
      expect(r.emportes.single.id, id);
      expect(e.estVide, isTrue);
    });
  });

  group('à l’écran', () {
    Future<void> tracer(WidgetTester t, List<Offset> points) async {
      final g = await t.startGesture(points.first);
      for (final p in points.skip(1)) {
        await g.moveTo(p);
      }
      await g.up();
      await t.pump();
    }

    Future<int> monter(WidgetTester t, Encre e, {bool couper = false}) async {
      var ratures = 0;
      await t.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: couper),
            child: FeuilleEncre(
              encre: e,
              libelle: 'feuille',
              surRature: () => ratures++,
            ),
          ),
        ),
      );
      final chiffre = courbe((t) => 30 + 10 * t, (t) => 20 + 20 * t);
      await tracer(t, chiffre);
      await tracer(t, [for (final p in zigzag(6)) p + const Offset(5, 15)]);
      return ratures;
    }

    testWidgets('s’efface en s’animant, sans laisser d’erreur', (t) async {
      final e = Encre();
      await monter(t, e);
      expect(e.estVide, isTrue);
      expect(t.hasRunningAnimations, isTrue);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });

    testWidgets('animations coupées : rien ne reste à jouer', (t) async {
      final e = Encre();
      await monter(t, e, couper: true);
      expect(e.estVide, isTrue);
      expect(t.hasRunningAnimations, isFalse);
    });
  });

  test('cadre', () {
    expect(
      cadreDeRature(const [Offset(1, 2), Offset(3, 0)]),
      const Rect.fromLTRB(1, 0, 3, 2),
    );
  });
}
