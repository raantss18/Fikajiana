import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:fikajiana/comprendre/signes.dart';
import 'package:fikajiana/comprendre/trace_ligne.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Dessin = List<List<(double, double)>>;

List<Trait> _fixture(String dossier, String nom) => [
  for (final t in jsonDecode(
    File('test/fixtures/$dossier/$nom.json').readAsStringSync(),
  ) as List<dynamic>)
    Trait.depuisDocument(t as Map<String, dynamic>),
];

/// Un signe dessiné dans la boîte (x, y, l, h), un point tous les 2 px,
/// avec un léger tremblement : la main n'est pas une règle.
List<Trait> _signe(_Dessin d, double x, double y, double l, double h) => [
  for (final (n, t) in d.indexed)
    Trait.depuisDocument({
      'points': [
        for (var i = 0; i + 1 < t.length; i++)
          for (final p in _segment(t[i], t[i + 1], x, y, l, h, n)) p,
        [x + t.last.$1 * l, y + t.last.$2 * h, 0.5],
      ],
    }),
];

List<List<double>> _segment(
  (double, double) a,
  (double, double) b,
  double x,
  double y,
  double l,
  double h,
  int graine,
) {
  final (ax, ay) = (x + a.$1 * l, y + a.$2 * h);
  final (bx, by) = (x + b.$1 * l, y + b.$2 * h);
  final n = math.max(
    1,
    (math.sqrt(math.pow(bx - ax, 2) + math.pow(by - ay, 2)) / 2).ceil(),
  );
  return [
    for (var k = 0; k < n; k++)
      [
        ax + (bx - ax) * k / n + 0.3 * math.sin(k + graine),
        ay + (by - ay) * k / n + 0.3 * math.cos(k + graine),
        0.5,
      ],
  ];
}

/// Une ligne : des signes posés de gauche à droite.
List<Trait> _ligne(List<List<Trait>> signes) => [for (final s in signes) ...s];

// Les signes, dessinés à la main pour ces essais (pas les modèles).
const _Dessin _deux = [
  [
    (.1, .22),
    (.32, .02),
    (.68, .04),
    (.88, .25),
    (.72, .52),
    (.08, .98),
    (.92, .97),
  ],
];
const _Dessin _un = [
  [(.2, .25), (.55, 0), (.55, 1)],
];
const _Dessin _trois = [
  [
    (.1, .12),
    (.45, 0),
    (.8, .15),
    (.7, .4),
    (.4, .5),
    (.75, .6),
    (.85, .82),
    (.55, 1),
    (.1, .9),
  ],
];
const _Dessin _cinq = [
  [
    (.85, .02),
    (.22, .02),
    (.18, .45),
    (.6, .38),
    (.9, .65),
    (.7, .95),
    (.1, .95),
  ],
];
const _Dessin _sept = [
  [(.05, .02), (.95, .02), (.35, 1)],
];
const _Dessin _plus = [
  [(0, .5), (1, .5)],
  [(.5, 0), (.5, 1)],
];
const _Dessin _egal = [
  [(0, .2), (1, .2)],
  [(0, .8), (1, .8)],
];
const _Dessin _moins = [
  [(0, .5), (1, .5)],
];
const _Dessin _croix = [
  [(0, 0), (1, 1)],
  [(1, 0), (0, 1)],
];
const _Dessin _z = [
  [(.05, .05), (.95, .02), (.08, .95), (.95, .98)],
];
const _Dessin _e = [
  [
    (.12, .55),
    (.88, .5),
    (.82, .22),
    (.5, .02),
    (.15, .22),
    (.08, .62),
    (.38, .98),
    (.92, .85),
  ],
];
const _Dessin _t = [
  [(.38, 0), (.38, .82), (.52, 1), (.72, .92)],
  [(.05, .32), (.72, .3)],
];
const _Dessin _d = [
  [
    (.62, .55),
    (.35, .42),
    (.1, .58),
    (.06, .86),
    (.3, 1),
    (.58, .88),
    (.66, 0),
    (.66, 1),
  ],
];
const _Dessin _pi = [
  [(0, .1), (1, .06)],
  [(.3, .08), (.24, 1)],
  [(.7, .08), (.74, 1)],
];

/// Hauteur d'un chiffre : 40 ; d'une minuscule basse : 22. Pied à 100.
List<Trait> _chiffre(_Dessin d, double x) => _signe(d, x, 60, 32, 40);
List<Trait> _basse(_Dessin d, double x) => _signe(d, x, 78, 22, 22);

void main() {
  group('les traits d’Antsa (Pad 7, téléphone)', () {
    test('lus au tracé, juste', () {
      expect(lireAuTrace(_fixture('pad7', 'derivee_f')), "f'(x)=");
      expect(lireAuTrace(_fixture('pad7', 'e_x_egal_7')), 'e^{x}=7');
      expect(lireAuTrace(_fixture('pad7', 'trente_fois_8')), r'30\times8');
      expect(lireAuTrace(_fixture('pad7', 'AB_egal')), 'AB=');
      expect(lireAuTrace(_fixture('telephone', 'un_plus_un')), '1+1');
      expect(lireAuTrace(_fixture('telephone', 'un_plus_un_2')), '1+1');
    });

    test('ce qui doute va au modèle, jamais lu faux', () {
      for (final (dossier, nom) in [
        ('pad7', 'det_2x2_40'),
        ('pad7', 'det_3x3_72'),
        ('pad7', 'developper'),
        ('pad7', 'fleche_plot'),
        ('pad7', 'longueur'),
        ('pad7', 'matrice_inverse'),
        ('pad7', 'norme_AB'),
        ('pad7', 'point_A'),
        ('pad7', 'point_B'),
        ('pad7', 'premier_17'),
        ('pad7', 'puissances_de_10'),
        ('pad7', 'vecteur_AB'),
        ('telephone', 'limite'),
        ('telephone', 'matrice_carre'),
        ('telephone', 'point_A_1_moins_1'),
        ('telephone', 'point_A_3_moins_1'),
      ]) {
        expect(lireAuTrace(_fixture(dossier, nom)), isNull, reason: nom);
      }
    });
  });

  group('chaque minuscule, de deux façons (ADR 0037)', () {
    // Dessinées à la main pour ces essais, dans un carré : la hauteur vaut 1.
    const variantes = <String, List<_Dessin>>{
      'a': [
        [
          [
            (.8, .25),
            (.5, .02),
            (.12, .28),
            (.08, .72),
            (.38, .98),
            (.72, .8),
            (.84, .35),
            (.86, .05),
            (.88, .85),
            (.98, .98),
          ],
        ],
        [
          [
            (.82, .25),
            (.5, .03),
            (.1, .35),
            (.1, .75),
            (.4, .98),
            (.75, .82),
            (.84, .4),
          ],
          [(.86, .02), (.88, .98)],
        ],
      ],
      'b': [
        [
          [
            (.12, 0),
            (.1, .98),
            (.12, .68),
            (.38, .45),
            (.62, .52),
            (.66, .82),
            (.4, .99),
            (.12, .92),
          ],
        ],
        [
          [(.1, .02), (.1, .98)],
          [(.1, .62), (.36, .44), (.62, .55), (.6, .86), (.34, .99), (.1, .9)],
        ],
      ],
      'c': [
        [
          [
            (.88, .18),
            (.55, .02),
            (.15, .22),
            (.03, .58),
            (.22, .92),
            (.58, 1),
            (.92, .82),
          ],
        ],
        [
          [(.85, .12), (.5, 0), (.12, .3), (.1, .7), (.45, .98), (.9, .9)],
        ],
      ],
      'd': [
        [
          [
            (.58, .52),
            (.32, .45),
            (.08, .62),
            (.06, .88),
            (.32, .99),
            (.56, .86),
            (.64, .02),
            (.66, .98),
          ],
        ],
        [
          [(.6, .52), (.34, .44), (.08, .6), (.06, .86), (.3, .99), (.58, .86)],
          [(.66, 0), (.66, 1)],
        ],
      ],
      'e': [
        _e,
        [
          [
            (.1, .5),
            (.8, .48),
            (.75, .2),
            (.45, .02),
            (.12, .25),
            (.1, .7),
            (.4, .98),
            (.85, .88),
          ],
        ],
      ],
      'k': [
        [
          [(.12, 0), (.1, 1)],
          [(.62, .42), (.12, .7), (.68, .98)],
        ],
        [
          [
            (.1, 0),
            (.12, .98),
            (.12, .68),
            (.5, .42),
            (.58, .52),
            (.15, .7),
            (.66, .98),
          ],
        ],
      ],
      'n': [
        [
          [
            (.06, .06),
            (.1, .98),
            (.12, .38),
            (.42, .02),
            (.74, .12),
            (.84, .52),
            (.86, .98),
          ],
        ],
        [
          [(.1, 0), (.12, 1)],
          [(.12, .4), (.42, .02), (.78, .12), (.84, .5), (.86, 1)],
        ],
      ],
      't': [
        [
          [(.36, 0), (.36, .84), (.5, 1), (.72, .9)],
          [(.06, .32), (.68, .28)],
        ],
        [
          [(.34, 0), (.36, 1)],
          [(.04, .3), (.7, .32)],
        ],
      ],
      'u': [
        [
          [
            (.06, 0),
            (.06, .68),
            (.3, .98),
            (.66, .95),
            (.84, .58),
            (.86, 0),
            (.86, .98),
          ],
        ],
        [
          [
            (.04, .02),
            (.06, .7),
            (.32, .99),
            (.64, .96),
            (.84, .62),
            (.86, .02),
            (.86, .86),
            (.98, .98),
          ],
        ],
      ],
      'v': [
        [
          [(0, .02), (.46, .98), (.9, .02)],
        ],
        [
          [(.02, .08), (.14, 0), (.3, .52), (.46, .98), (.72, .38), (.94, .04)],
        ],
      ],
      'x': [
        _croix,
        [
          [(0, .02), (.32, .18), (.4, .5), (.3, .84), (.02, .98)],
          [(.98, 0), (.62, .16), (.52, .5), (.62, .86), (.98, 1)],
        ],
      ],
      'y': [
        [
          [(0, 0), (.42, .52)],
          [(.8, 0), (.14, 1)],
        ],
        [
          [(.04, .02), (.4, .55)],
          [(.84, .04), (.45, .6), (.2, 1)],
        ],
      ],
      'z': [
        _z,
        [
          [(.05, .1), (.3, .02), (.9, .05), (.06, .95), (.5, .9), (.95, .98)],
        ],
      ],
      r'\pi': [
        _pi,
        [
          [(0, .14), (.3, .06), (1, .04)],
          [(.32, .08), (.22, .86)],
          [(.7, .06), (.7, .74), (.88, .86)],
        ],
      ],
    };

    for (final MapEntry(key: lettre, value: dessins) in variantes.entries) {
      test(lettre, () {
        for (final (i, d) in dessins.indexed) {
          final traits = _signe(d, 0, 0, 40, 40);
          final lu = reconnaitreSigne([
            for (final t in traits) [for (final p in t.points) p.position],
          ]);
          expect(lu?.keys, contains(lettre), reason: '$lettre, façon $i');
        }
      });
    }
  });

  group('minuscules et ambiguïtés (ADR 0037)', () {
    test('2x+1 : le 2 est plus haut que le x, le x pas entre deux nombres', () {
      expect(
        lireAuTrace(
          _ligne([
            _chiffre(_deux, 0),
            _basse(_croix, 42),
            _signe(_plus, 74, 68, 24, 24),
            _chiffre(_un, 108),
          ]),
        ),
        '2x+1',
      );
    });

    test('3×5 : la croix entre deux nombres', () {
      expect(
        lireAuTrace(
          _ligne([
            _chiffre(_trois, 0),
            _signe(_croix, 42, 71, 18, 18),
            _chiffre(_cinq, 70),
          ]),
        ),
        r'3\times5',
      );
    });

    test('10+5x : 1, 0 et 5 sans lettre voisine sont des chiffres', () {
      const zero = <List<(double, double)>>[
        [
          (.5, .02),
          (.18, .15),
          (.08, .5),
          (.2, .88),
          (.5, .98),
          (.8, .86),
          (.9, .5),
          (.8, .12),
          (.5, .02),
        ],
      ];
      expect(
        lireAuTrace(
          _ligne([
            _chiffre(_un, 0),
            _chiffre(zero, 36),
            _signe(_plus, 78, 68, 24, 24),
            _chiffre(_cinq, 112),
            _basse(_croix, 154),
          ]),
        ),
        '10+5x',
      );
    });

    test('xz : le z a la taille du x', () {
      expect(lireAuTrace(_ligne([_basse(_croix, 0), _basse(_z, 32)])), 'xz');
    });

    test('x^2 : un exposant au-dessus de la moitié du x', () {
      expect(
        lireAuTrace(_ligne([_basse(_croix, 0), _signe(_deux, 26, 56, 18, 24)])),
        'x^{2}',
      );
    });

    test('t+e : un t n’est pas un +', () {
      expect(
        lireAuTrace(
          _ligne([
            _signe(_t, 0, 64, 20, 36),
            _signe(_plus, 30, 68, 24, 24),
            _basse(_e, 64),
          ]),
        ),
        't+e',
      );
    });

    test('2π', () {
      expect(
        lireAuTrace(_ligne([_chiffre(_deux, 0), _signe(_pi, 42, 76, 26, 24)])),
        r'2\pi',
      );
    });

    test('det, trois lettres de suite : au modèle', () {
      expect(
        lireAuTrace(
          _ligne([
            _signe(_d, 0, 62, 22, 38),
            _basse(_e, 30),
            _signe(_t, 60, 64, 20, 36),
          ]),
        ),
        isNull,
      );
    });
  });

  group('fractions, racines, décimaux', () {
    test(r'\frac{1}{x+2} : chaque étage lu au tracé', () {
      expect(
        lireAuTrace(
          _ligne([
            _signe(_un, 40, 20, 20, 36),
            _signe(_moins, 0, 64, 100, 0),
            _signe(_croix, 4, 76, 22, 22),
            _signe(_plus, 34, 76, 22, 22),
            _signe(_deux, 66, 68, 24, 32),
          ]),
        ),
        r'\frac{1}{x+2}',
      );
    });

    test(r'\frac{1}{x}', () {
      expect(
        lireAuTrace(
          _ligne([
            _signe(_un, 12, 20, 20, 36),
            _signe(_moins, 0, 64, 44, 0),
            _signe(_croix, 10, 76, 22, 22),
          ]),
        ),
        r'\frac{1}{x}',
      );
    });

    test(r'\sqrt{2} et 3+\sqrt{5}', () {
      const racine = <List<(double, double)>>[
        [(0, .55), (.12, .45), (.25, 1), (.38, 0), (1, 0)],
      ];
      expect(
        lireAuTrace(
          _ligne([_signe(racine, 0, 50, 70, 56), _chiffre(_deux, 30)]),
        ),
        r'\sqrt{2}',
      );
      expect(
        lireAuTrace(
          _ligne([
            _chiffre(_trois, 0),
            _signe(_plus, 42, 68, 24, 24),
            _signe(racine, 76, 50, 70, 56),
            _chiffre(_cinq, 106),
          ]),
        ),
        r'3+\sqrt{5}',
      );
    });

    test('3,5 et 2.7', () {
      const virgule = <List<(double, double)>>[
        [(.6, 0), (.5, .5), (.1, 1)],
      ];
      const point = <List<(double, double)>>[
        [(0, 0), (1, 1), (0, 1), (1, 0)],
      ];
      expect(
        lireAuTrace(
          _ligne([
            _chiffre(_trois, 0),
            _signe(virgule, 36, 92, 6, 14),
            _chiffre(_cinq, 46),
          ]),
        ),
        '3{,}5',
      );
      expect(
        lireAuTrace(
          _ligne([
            _chiffre(_deux, 0),
            _signe(point, 36, 96, 3, 3),
            _chiffre(_sept, 44),
          ]),
        ),
        '2.7',
      );
    });

    test('2·3 : un point à mi-hauteur doute', () {
      const point = <List<(double, double)>>[
        [(0, 0), (1, 1), (0, 1), (1, 0)],
      ];
      expect(
        lireAuTrace(
          _ligne([
            _chiffre(_deux, 0),
            _signe(point, 36, 79, 3, 3),
            _chiffre(_trois, 44),
          ]),
        ),
        isNull,
      );
    });
  });

  group('leurres : une minuscule n’est jamais un chiffre', () {
    // Le `n` cursif d'Antsa : une attaque, deux bosses, d'un seul trait.
    const n = <List<(double, double)>>[
      [
        (0, .95),
        (.1, .15),
        (.18, .02),
        (.24, .95),
        (.32, .35),
        (.55, .03),
        (.74, .18),
        (.78, .92),
        (.98, .98),
      ],
    ];
    const g = <List<(double, double)>>[
      [
        (.72, .18),
        (.42, .02),
        (.12, .16),
        (.1, .4),
        (.4, .5),
        (.68, .36),
        (.7, .02),
        (.7, .82),
        (.48, 1),
        (.15, .9),
      ],
    ];
    List<List<Offset>> dessin(List<Trait> s) => [
      for (final t in s) [for (final p in t.points) p.position],
    ];

    test('un n à deux bosses ne devient pas un 4', () {
      final s = dessin(_signe(n, 0, 0, 40, 30));
      expect(reconnaitreChiffre(s), isNull);
      expect(reconnaitreSigne(s)?.keys, isNot(contains('4')));
      expect(
        lireAuTrace(
          _ligne([
            _signe(n, 0, 78, 30, 22),
            _signe(_egal, 40, 82, 24, 14),
            _chiffre(_deux, 74),
          ]),
        ),
        isNot(startsWith('4')),
      );
    });

    // Depuis l'ADR 0046, le `g` est une vraie minuscule : ce `y` cursif
    // l'emporte sur lui de 0,2 au moins, et n'est jamais un `9`.
    test('un y cursif d’un trait, proche du g : un y, ni g ni 9', () {
      const y = <List<(double, double)>>[
        [
          (0, 0),
          (.02, .32),
          (.3, .5),
          (.6, .32),
          (.6, 0),
          (.6, .82),
          (.4, 1),
          (.06, .9),
        ],
      ];
      final lu = reconnaitreSigne(dessin(_signe(y, 0, 0, 40, 40)))?.keys;
      expect(lu, contains('y'));
      expect(lu, isNot(contains('g')));
      expect(lu, isNot(contains('9')));
    });

    test('un g n’est ni un 9 ni un q', () {
      final s = dessin(_signe(g, 0, 0, 24, 40));
      expect(reconnaitreChiffre(s), isNull);
      final lu = reconnaitreSigne(s)?.keys ?? const <String>[];
      expect(lu, isNot(contains('9')));
      expect(lu, isNot(contains('q')));
    });
  });
}
