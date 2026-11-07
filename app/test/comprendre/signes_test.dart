import 'dart:math' as math;

import 'package:fikajiana/comprendre/signes.dart';
import 'package:flutter_test/flutter_test.dart';

List<List<Offset>> trace(List<List<(double, double)>> d, {double e = 40}) => [
  for (final t in d) [for (final (x, y) in t) Offset(x * e, y * e)],
];

void main() {
  group('un chiffre se reconnaît sur son tracé', () {
    const dessins = <String, List<List<(double, double)>>>{
      '0': [
        [
          (.5, .02),
          (.2, .12),
          (.1, .5),
          (.2, .88),
          (.5, .98),
          (.8, .88),
          (.9, .5),
          (.8, .12),
          (.5, .02),
        ],
      ],
      '1': [
        [(.48, 0), (.52, 1)],
      ],
      '2': [
        [
          (.12, .22),
          (.35, .02),
          (.72, .05),
          (.85, .25),
          (.08, .98),
          (.92, .96),
        ],
      ],
      '7': [
        [(.08, .02), (.92, .02), (.38, .98)],
      ],
    };
    for (final MapEntry(key: chiffre, value: d) in dessins.entries) {
      test(chiffre, () => expect(reconnaitreChiffre(trace(d)), chiffre));
    }
    test('la taille ne compte pas', () {
      expect(reconnaitreChiffre(trace(dessins['7']!, e: 300)), '7');
    });
  });

  test('une capitale se reconnaît', () {
    expect(
      reconnaitreCapitale(
        trace([
          [(.02, .98), (.5, .02), (.98, .98)],
          [(.22, .6), (.78, .6)],
        ]),
      ),
      'A',
    );
  });

  test('un gribouillis n’est pas un chiffre', () {
    final r = math.Random(1);
    final bruit = [
      [
        for (var i = 0; i < 60; i++)
          Offset(r.nextDouble() * 40, r.nextDouble() * 40),
      ],
    ];
    expect(reconnaitreChiffre(bruit), isNull);
  });
}
