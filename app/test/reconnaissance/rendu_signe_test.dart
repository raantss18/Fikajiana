import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:fikajiana/reconnaissance/rendu_signe.dart';
import 'package:flutter_test/flutter_test.dart';

List<List<Offset>> _fixture(String nom) => [
  for (final t in jsonDecode(
    File('test/fixtures/$nom.json').readAsStringSync(),
  ) as List<dynamic>)
    [
      for (final p in (t as Map<String, dynamic>)['points'] as List<dynamic>)
        Offset(
          ((p as List<dynamic>)[0] as num).toDouble(),
          (p[1] as num).toDouble(),
        ),
    ],
];

void main() {
  final references =
      (jsonDecode(File('test/fixtures/rendu_signes.json').readAsStringSync())
              as Map<String, dynamic>)['signes']
          as List<dynamic>;

  test('rendu et mesures comme rendu.py (contrat v1, ADR 0040)', () {
    final parFixture = <String, List<Map<String, dynamic>>>{};
    for (final r in references.cast<Map<String, dynamic>>()) {
      parFixture.putIfAbsent(r['fixture'] as String, () => []).add(r);
    }
    var ecartTotal = 0.0;
    var pixels = 0;
    var pire = 0.0;
    for (final MapEntry(key: nom, value: signes) in parFixture.entries) {
      final tous = _fixture(nom);
      List<List<Offset>> traitsDe(Map<String, dynamic> r) => [
        for (final i in (r['traits'] as List<dynamic>).cast<int>()) tous[i],
      ];
      final mediane = hauteurMediane([for (final r in signes) traitsDe(r)]);
      for (final r in signes) {
        final traits = traitsDe(r);
        final attendue = (r['case'] as List<dynamic>).cast<num>();
        final c = caseDuSigne(traits, tous, mediane);
        expect(
          c.top,
          closeTo(attendue[1], 1e-3),
          reason: '$nom ${r['classe']}',
        );
        expect(
          c.height,
          closeTo(attendue[3], 1e-3),
          reason: '$nom ${r['classe']}',
        );
        final mesures = mesurerSigne(traits, c);
        final refMesures = (r['mesures'] as List<dynamic>).cast<num>();
        for (var i = 0; i < nombreMesures; i++) {
          expect(mesures[i], closeTo(refMesures[i], 1e-3));
        }
        final image = rendreSigne(traits, c.height);
        final code = r['image16'] as String;
        var ecart = 0.0;
        for (var i = 0; i < image.length; i++) {
          final ref = '0123456789abcdefg'.indexOf(code[i]) / 16;
          ecart += (image[i] - ref).abs();
        }
        ecartTotal += ecart;
        pixels += image.length;
        // Part d'encre déplacée, rapportée à l'encre du signe.
        final encre = image.fold<double>(0, (s, v) => s + v);
        pire = math.max(pire, ecart / math.max(encre, 1e-6));
      }
    }
    final moyen = ecartTotal / pixels;
    // Visible dans la sortie du test : l'écart mesuré.
    // ignore: avoid_print
    print(
      'rendu Dart / rendu.py : écart moyen ${moyen.toStringAsFixed(4)} '
      'par pixel, pire ${(pire * 100).toStringAsFixed(1)} % de l’encre',
    );
    expect(moyen, lessThan(0.001));
    expect(pire, lessThan(0.02));
  });

  test('un point n’est pas agrandi au-delà de 0,15 H', () {
    final image = rendreSigne([
      [const Offset(10, 10)],
    ], 40);
    final encre = image.fold<double>(0, (s, v) => s + v);
    expect(encre, greaterThan(0));
    expect(encre, lessThan(4));
  });
}
