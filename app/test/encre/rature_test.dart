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

/// Lit des traits relevés au vrai stylet : `x,y x,y …`.
List<Offset> releve(String points) => [
  for (final p in points.split(' '))
    Offset(double.parse(p.split(',').first), double.parse(p.split(',').last)),
];

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

    // Relevés sur le Pad 7 : ces ratures-là n'effaçaient rien en 0.6.0.
    const ratures = {
      'a':
          '0,0 1,4 1,10 2,19 3,27 5,30 5,32 5,31 7,28 8,25 10,20 12,14 13,10 '
          '15,7 15,5 16,4 16,5 18,7 19,12 19,17 20,21 20,24 20,26 20,28 20,27 '
          '22,25 24,22 26,16 28,11 30,7 31,4 33,3 33,2 34,3 35,7 36,14 37,19 '
          '37,23 38,25 38,27 38,26 39,23 40,17 42,12 44,7 46,4 47,3 49,2 51,4 '
          '53,10 55,19 57,27 58,33 59,39 60,44',
      'b':
          '0,2 1,4 1,9 1,18 2,28 4,39 7,46 8,48 9,47 10,41 11,34 13,26 14,19 '
          '16,10 18,4 20,1 20,0 20,1 23,6 25,13 26,21 27,25 27,28 28,27 29,24 '
          '30,19 32,13 33,8 34,6 36,7 38,13 39,20 40,24 40,26 41,25 43,20 '
          '46,15 49,9 51,5 53,2 54,2 57,10 61,24 64,40 68,53 71,61',
      'c':
          '0,5 1,6 1,12 2,21 3,30 4,36 5,39 5,41 6,41 6,40 7,37 9,32 11,25 '
          '13,17 14,11 14,5 15,2 15,0 16,0 18,2 20,8 21,14 22,21 22,26 22,29 '
          '22,31 23,32 23,31 24,28 26,23 29,18 31,13 33,9 34,7 34,6 34,7 '
          '34,12 34,18 35,21 35,24 35,25 36,23 38,20 41,16 43,12 45,9 46,7 '
          '47,7 48,8 51,14 53,22 55,30 57,34 57,36',
    };
    for (final MapEntry(key: nom, value: points) in ratures.entries) {
      test('une rature au vrai stylet : $nom', () {
        expect(estRature(releve(points)), isTrue);
      });
    }

    test("le `m` relevé au vrai stylet n'est pas une rature", () {
      expect(
        estRature(
          releve(
            '0,4 1,4 2,3 2,2 3,1 3,0 4,0 5,4 7,10 8,18 9,28 9,34 9,39 8,42 '
            '9,37 10,30 11,21 13,14 14,9 15,7 16,5 17,5 18,5 20,5 22,5 23,5 '
            '24,6 24,9 24,15 24,22 24,29 23,32 23,33 23,31 24,28 24,25 24,23 '
            '25,21 25,19 26,17 27,14 30,11 33,9 36,7 37,6 38,5 39,6 41,8 '
            '42,13 43,19 43,25 44,29 45,33 46,35 47,36 48,37',
          ),
        ),
        isFalse,
      );
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

    void tracerReleve(Encre e, String points) => tracer(e, releve(points));

    // Relevés au vrai stylet sur le Pad 7.
    const chiffreBarre =
        '309,534 314,530 330,525 339,524 341,525 340,528 337,539 334,552 '
        '332,562 331,568 330,571 330,573 331,575';
    const petiteRature =
        '302,528 302,528 303,535 305,552 307,573 307,582 307,583 307,581 '
        '310,572 314,562 318,551 321,540 322,538 324,542 326,550 327,556 '
        '327,558 327,558 327,556 329,549 332,541 334,537 336,537 340,543 '
        '342,546 344,549 345,551 347,554';

    test('une rature vite faite efface ce qu’elle couvre', () {
      final e = Encre();
      tracerReleve(e, chiffreBarre);
      tracerReleve(e, petiteRature);
      expect(e.raturerDernierTrait()?.emportes, hasLength(1));
      expect(e.traits, isEmpty);
    });

    test('la même forme à côté de l’encre reste de l’écriture', () {
      final e = Encre();
      tracer(e, ailleurs);
      tracerReleve(e, petiteRature);
      expect(e.raturerDernierTrait(), isNull);
      expect(e.traits, hasLength(2));
    });

    test('une rature longue barre toute une expression', () {
      expect(
        estRature(
          releve(
            '682,483 683,482 683,485 683,497 684,513 684,520 684,521 687,515 '
            '690,508 695,499 699,489 701,484 702,484 703,493 704,503 705,507 '
            '705,508 709,505 713,500 717,493 721,486 723,483 725,490 727,498 '
            '728,502 728,503 730,500 734,494 737,488 740,484 741,483 742,483 '
            '744,490 745,496 745,498 746,497 752,492 760,485 771,479 779,474 '
            '783,472 786,476 790,485 792,491 796,495 805,499',
          ),
        ),
        isTrue,
      );
    });

    test('un trait qui dépasse de la rature part avec elle', () {
      final e = Encre();
      tracerReleve(
        e,
        '510,513 510,512 513,508 520,505 527,502 532,499 535,498 536,497 '
        '538,502 538,517 537,538 534,555 532,563 531,568 531,569 532,569',
      );
      tracerReleve(
        e,
        '531,511 531,511 532,512 534,524 536,545 537,563 537,566 538,564 '
        '542,556 546,544 549,530 553,517 555,507 556,504 556,515 558,535 '
        '560,547 561,551 563,552 566,549 572,542 577,532 581,521 583,515 '
        '583,517 584,529 585,540 586,543 588,541 591,536 595,528 596,526 '
        '597,528 600,539 602,544 603,545 604,545 609,540 615,532 619,523 '
        '622,518 622,517 624,521 626,528 629,532 631,534 633,534 637,530 '
        '640,524',
      );
      expect(e.raturerDernierTrait(), isNotNull);
      expect(e.traits, isEmpty);
    });

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
