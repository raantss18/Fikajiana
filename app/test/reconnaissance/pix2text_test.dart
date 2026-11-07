import 'dart:math' as math;

import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/reconnaissance/pix2text.dart';
import 'package:fikajiana/reconnaissance/rasteriser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Decodeur', () {
    final decodeur = Decodeur({
      '<pad>': 0,
      '<s>': 1,
      '</s>': 2,
      '<unk>': 3,
      '<mask>': 4,
      r'\frac': 5,
      'Ġ{': 6,
      'Ġ1': 7,
      'Ġ}': 8,
    });

    test('Ġ redevient une espace, les jetons spéciaux disparaissent', () {
      expect(decodeur.decoder([2, 5, 6, 7, 8, 2]), r'\frac { 1 }');
    });

    test('un jeton inconnu est ignoré', () {
      expect(decodeur.decoder([5, 999]), r'\frac');
    });
  });

  group('recherche en faisceau', () {
    // 0 : fin ; le modèle préfère 1, puis 2 ; après 2, il est très sûr.
    Future<List<double>> etape(List<int> jetons) async {
      if (jetons.length >= 3) return [9, 0, 0];
      if (jetons.last == 2) return [0, 0, 8];
      return [0, 2, 1.9];
    }

    test('rend plusieurs lectures, la meilleure d’abord', () async {
      final h = await decoderEnFaisceau(
        depart: 0,
        fin: 0,
        largeur: 2,
        jetonsMaximum: 6,
        etape: etape,
      );
      expect(h, hasLength(2));
      expect(h.every((x) => x.finie), isTrue);
      expect(h.first.scoreMoyen, greaterThanOrEqualTo(h.last.scoreMoyen));
      expect(h.map((x) => x.jetons[1]).toSet(), containsAll([2]));
    });

    test('une largeur de 1 revient à la lecture simple', () async {
      final h = await decoderEnFaisceau(
        depart: 0,
        fin: 0,
        largeur: 1,
        jetonsMaximum: 6,
        etape: (j) async => j.length >= 3 ? [9, 0] : [0, 5],
      );
      expect(h.single.jetons, [0, 1, 1]);
    });

    test('s’arrête à la limite de jetons', () async {
      final h = await decoderEnFaisceau(
        depart: 0,
        fin: 0,
        largeur: 2,
        jetonsMaximum: 4,
        etape: (_) async => [0, 5, 4],
      );
      expect(h.every((x) => x.jetons.length <= 5), isTrue);
    });

    test('log-softmax : somme des probabilités à 1, ordre gardé', () {
      final p = logSoftmax([1, 2, 3]);
      expect(p.map(math.exp).reduce((a, b) => a + b), closeTo(1, 1e-9));
      expect(p[2], greaterThan(p[0]));
    });
  });

  group('normaliserLatex', () {
    test(r'ignore espaces, \left, \right, \dfrac et les fines', () {
      expect(
        normaliserLatex(r'\dfrac { 1 } { 2 } \, \left( x \right)'),
        r'\frac{1}{2}(x)',
      );
    });

    test(r'\mathrm{d} vaut d', () {
      expect(normaliserLatex(r'\int x \, \mathrm { d } x'), isNot(isEmpty));
      expect(normaliserLatex(r'\mathrm{d}x'), 'dx');
    });

    test(r'\right n est retiré que comme mot entier', () {
      expect(normaliserLatex(r'\rightarrow'), r'\rightarrow');
    });

    test('ne confond pas des expressions différentes', () {
      expect(normaliserLatex('x^{2}'), isNot(normaliserLatex('x_{2}')));
    });
  });

  testWidgets('la rastérisation donne un tenseur noir sur blanc normalisé', (
    tester,
  ) async {
    final encre = Encre()
      ..commencer(const PointEncre(10, 10, 1))
      ..prolonger(const PointEncre(200, 100, 1));

    final tenseur = await tester.runAsync(() async {
      final image = await rasteriser(encre);
      expect(image, isNotNull);
      return await versTenseur(image!);
    });

    expect(tenseur!.length, 3 * tailleModele * tailleModele);
    expect(tenseur.reduce((a, b) => a > b ? a : b), closeTo(1, 0.01));
    expect(tenseur.reduce((a, b) => a < b ? a : b), lessThan(-0.5));
  });

  testWidgets('sans encre, pas d’image', (tester) async {
    final image = await tester.runAsync(() => rasteriser(Encre()));
    expect(image, isNull);
  });
}
