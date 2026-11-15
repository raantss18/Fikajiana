import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:fikajiana/comprendre/blocs.dart';
import 'package:fikajiana/comprendre/structure.dart';
import 'package:fikajiana/comprendre/trace_ligne.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/reconnaissance/lecteur.dart';
import 'package:flutter_test/flutter_test.dart';

List<Trait> _traits(String dossier, String nom) => [
  for (final t in jsonDecode(
    File('test/fixtures/$dossier/$nom.json').readAsStringSync(),
  ) as List<dynamic>)
    Trait.depuisDocument(t as Map<String, dynamic>),
];

/// Le modèle : du bruit sur une ligne, mais un `2` seul se lit (comme sur
/// le téléphone, où seul le `4` ouvert devenait `1/1`).
class _Bruit extends Lecteur {
  @override
  Future<String> lire(List<Trait> traits) async =>
      traits.length == 1 ? '2' : r'\varLambda';
}

/// Un trait dessiné point par point, de (x0, y0) à (x1, y1).
Trait _segment(double x0, double y0, double x1, double y1) {
  final n = math.max(2, ((x1 - x0).abs() + (y1 - y0).abs()).round());
  return Trait.depuisDocument({
    'auStylet': true,
    'points': [
      for (var k = 0; k <= n; k++)
        [x0 + (x1 - x0) * k / n, y0 + (y1 - y0) * k / n, 0.3],
    ],
  });
}

/// Un toucher du stylet : un seul point.
Trait _toucher(double x, double y) => Trait.depuisDocument({
  'auStylet': true,
  'points': [
    [x, y, 0.3],
  ],
});

/// `=` à droite de `30×8` (chiffres de y = 270 à 319 sur le Pad 7).
List<Trait> _egal() => [
  _segment(500, 288, 526, 288),
  _segment(500, 301, 526, 301),
];

void main() {
  group('factorielle écrite à la main (ADR 0071)', () {
    // Comme sur le Pad 7 d'Antsa (`53!=` lu `53.1`) : une hampe qui s'arrête
    // au-dessus de la ligne, et son point dessous, un peu à gauche.
    test('hampe et petit trait dessous : `!`, pas un point décimal', () {
      expect(
        lireAuTrace([
          ..._traits('pad7', 'trente_fois_8'),
          _segment(481, 272, 480, 305),
          _segment(477, 316, 479, 323),
          ..._egal(),
        ]),
        r'30\times8!=',
      );
    });

    test(
      'hampe et toucher du stylet dessous : `!`, le point n’est pas oublié',
      () {
        expect(
          lireAuTrace([
            ..._traits('pad7', 'trente_fois_8'),
            _segment(481, 272, 480, 305),
            _toucher(479, 318),
            ..._egal(),
          ]),
          r'30\times8!=',
        );
      },
    );

    test('le point tracé avant la hampe (plus à gauche) : toujours `!`', () {
      expect(
        lireAuTrace([
          ..._traits('pad7', 'trente_fois_8'),
          _segment(476, 316, 478, 324),
          _segment(481, 272, 481, 305),
          ..._egal(),
        ]),
        r'30\times8!=',
      );
    });
  });

  group('factorielle comme sur la capture d\u2019Antsa (53! lu 53.1)', () {
    // Hampe qui s'arrête au-dessus de la ligne ; son point est un petit
    // crochet tracé loin dessous, sous la ligne, un peu à gauche.
    Trait polyligne(List<(double, double)> p) => Trait.depuisDocument({
      'auStylet': true,
      'points': [
        for (var k = 0; k + 1 < p.length; k++)
          for (var j = 0; j < 8; j++)
            [
              p[k].$1 + (p[k + 1].$1 - p[k].$1) * j / 8,
              p[k].$2 + (p[k + 1].$2 - p[k].$2) * j / 8,
              0.3,
            ],
        [p.last.$1, p.last.$2, 0.3],
      ],
    });
    final crochet = polyligne([(476.4, 333), (481.9, 328.5), (480.1, 339.8)]);
    for (final (nom, point) in [
      ('crochet d\u2019un trait', [crochet]),
      (
        'crochet en deux traits',
        [
          polyligne([(476.4, 333), (481.9, 328.5)]),
          polyligne([(481.9, 328.5), (480.1, 339.8)]),
        ],
      ),
      ('point très bas', [_segment(479, 340, 480, 346)]),
      ('toucher très bas', [_toucher(479, 342)]),
      ('crochet tracé avant la hampe', null),
    ]) {
      test(nom, () {
        expect(
          lireAuTrace([
            ..._traits('pad7', 'trente_fois_8'),
            if (point == null) crochet,
            _segment(481, 270, 481.5, 310),
            ...?point,
            ..._egal(),
          ]),
          r'30\times8!=',
        );
      });
    }
    test('hampe un peu penchée (au doigt)', () {
      expect(
        lireAuTrace([
          ..._traits('pad7', 'trente_fois_8'),
          _segment(484, 270, 479, 310),
          crochet,
          ..._egal(),
        ]),
        r'30\times8!=',
      );
    });
  });

  group('autres signes faits de points (ADR 0071)', () {
    // `3`, `0` et `8` de `30×8` (Pad 7), sans le `×`.
    List<Trait> avec(List<Trait> milieu) {
      final t = _traits('pad7', 'trente_fois_8');
      return [t[0], t[1], ...milieu, t[4]];
    }

    test('÷ aux points tapés : une division, pas un moins', () {
      expect(
        lireAuTrace(
          avec([
            _segment(385, 296, 420, 296),
            _toucher(402, 285),
            _toucher(402, 308),
          ]),
        ),
        r'30\div8',
      );
    });

    test('sans ses points, le plat reste un moins', () {
      expect(lireAuTrace(avec([_segment(385, 296, 420, 296)])), '30-8');
    });

    test('deux points tapés l’un sur l’autre : la division du collège', () {
      expect(
        lireAuTrace(avec([_toucher(400, 288), _toucher(400, 306)])),
        r'30\div8',
      );
    });

    test('point-virgule : jamais une virgule décimale', () {
      // `30;8` ne se calcule pas : la ligne va au modèle, au lieu de `30,8`.
      expect(
        lireAuTrace(avec([_segment(379, 316, 377, 325), _toucher(381, 306)])),
        isNull,
      );
    });

    test('un 1 suivi d’un point sur la ligne : décimal, jamais `!`', () {
      final un = _segment(385, 271, 385, 319);
      expect(
        lireAuTrace(avec([un, _segment(394, 315, 395, 319)])),
        anyOf('301.8', '301{,}8'),
      );
      // Le même point fait de deux petits traits, au doigt.
      expect(
        lireAuTrace(
          avec([
            un,
            _segment(393, 315, 395, 317),
            _segment(395, 317, 394, 319),
          ]),
        ),
        anyOf('301.8', '301{,}8'),
      );
    });

    test('virgule seule : toujours décimale', () {
      expect(
        lireAuTrace(avec([_segment(379, 316, 377, 325)])),
        anyOf('30.8', '30{,}8'),
      );
    });
  });

  group('une ligne lue sur son tracé, sans le modèle (ADR 0035)', () {
    test('1+1 du téléphone d’Antsa, dans ses deux formes', () {
      expect(lireAuTrace(_traits('telephone', 'un_plus_un')), '1+1');
      expect(lireAuTrace(_traits('telephone', 'un_plus_un_2')), '1+1');
    });

    test('30×8 du Pad 7', () {
      expect(lireAuTrace(_traits('pad7', 'trente_fois_8')), r'30\times8');
    });

    test("f'(x)= du Pad 7 : le f, l'apostrophe, le x en deux arcs", () {
      expect(lireAuTrace(_traits('pad7', 'derivee_f')), "f'(x)=");
    });

    test('ce qui doute va au modèle', () {
      expect(lireAuTrace(_traits('pad7', 'developper')), isNull);
      expect(lireAuTrace(_traits('telephone', 'limite')), isNull);
    });
  });

  group('matrice au carré du téléphone d’Antsa', () {
    test('le 4 ouvert et l’exposant 2 se lisent au tracé', () async {
      expect(
        await lireStructure(_Bruit(), _traits('telephone', 'matrice_carre')),
        r'\begin{pmatrix}3&-1\\2&4\end{pmatrix}^{2}=',
      );
    });
  });

  group('limite du téléphone d’Antsa', () {
    test('lim sous x → 0 de 1/x, mot et flèche au tracé', () async {
      expect(
        await lireStructure(_Limite(), _traits('telephone', 'limite')),
        r'\lim_{x \to 0} \frac{1}{x}',
      );
    });
  });
}

/// Ce que le modèle lit de chaque morceau sur l'ordinateur : `\lim` pour
/// le mot, `x` pour la variable, et la fraction.
class _Limite extends Lecteur {
  @override
  Future<String> lire(List<Trait> traits) async {
    // Le mot et la variable sont à gauche de la flèche, la cible juste à sa
    // droite, la fraction plus loin.
    final gauche = cadreDuGroupe(traits).left;
    if (gauche > 600) return r'\frac{1}{x}';
    if (traits.length == 3) return r'\lim';
    return gauche < 300 ? 'x' : '0';
  }
}
