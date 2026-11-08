import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:fikajiana/comprendre/blocs.dart';
import 'package:fikajiana/comprendre/signes.dart';
import 'package:fikajiana/comprendre/structure.dart';
import 'package:fikajiana/comprendre/trace_ligne.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/reconnaissance/lecteur.dart';
import 'package:flutter_test/flutter_test.dart';

// ADR 0046 : minuscules `s o l r p q g h m w`, noms de fonction, borne
// `k = 1` sous un Σ. Les dessins ici sont faits pour ces essais (pas les
// gabarits) ; les signes réels sont ceux d'Antsa, versés en CC0.

typedef _Dessin = List<List<(double, double)>>;

/// Un signe dessiné dans la boîte (x, y, l, h), un point tous les 2 px,
/// avec un léger tremblement.
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

List<Trait> _ligne(List<List<Trait>> signes) => [for (final s in signes) ...s];

List<List<Offset>> _dessin(List<Trait> s) => [
  for (final t in s) [for (final p in t.points) p.position],
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
const _Dessin _plus = [
  [(0, .5), (1, .5)],
  [(.5, 0), (.5, 1)],
];
const _Dessin _egal = [
  [(0, .2), (1, .2)],
  [(0, .8), (1, .8)],
];
const _Dessin _un = [
  [(.2, .25), (.55, 0), (.55, 1)],
];
const _Dessin _croix = [
  [(0, 0), (1, 1)],
  [(1, 0), (0, 1)],
];
const _Dessin _ouvrante = [
  [(.9, 0), (.25, .25), (.15, .6), (.9, 1)],
];
const _Dessin _fermante = [
  [(.1, 0), (.75, .25), (.85, .6), (.1, 1)],
];
const _Dessin _s = [
  [
    (.9, .12),
    (.55, .02),
    (.2, .06),
    (.12, .3),
    (.45, .5),
    (.78, .62),
    (.84, .82),
    (.52, .98),
    (.15, .96),
    (.02, .8),
  ],
];
const _Dessin _o = [
  [
    (.5, .02),
    (.15, .18),
    (.02, .5),
    (.18, .88),
    (.5, .98),
    (.85, .85),
    (.98, .48),
    (.8, .12),
    (.48, .03),
  ],
];
const _Dessin _n = [
  [(.08, 0), (.1, 1), (.12, .35), (.4, 0), (.75, .1), (.85, .5), (.88, 1)],
];
const _Dessin _c = [
  [(.9, .15), (.5, 0), (.1, .25), (.08, .7), (.45, 1), (.9, .85)],
];
const _Dessin _a = [
  [
    (.85, .2),
    (.5, 0),
    (.1, .3),
    (.05, .7),
    (.35, 1),
    (.7, .85),
    (.85, .4),
    (.88, 0),
    (.88, .8),
    (1, 1),
  ],
];
const _Dessin _t = [
  [(.38, 0), (.38, .82), (.52, 1), (.72, .92)],
  [(.05, .32), (.72, .3)],
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
const _Dessin _baton = [
  [(.5, 0), (.5, 1)],
];
const _Dessin _point = [
  [(.3, .3), (.7, .3), (.7, .7), (.3, .7), (.3, .3)],
];
const _Dessin _g = [
  [
    (.75, .12),
    (.42, 0),
    (.1, .12),
    (.08, .38),
    (.4, .5),
    (.72, .35),
    (.74, .02),
    (.74, .78),
    (.5, 1),
    (.12, .92),
  ],
];
const _Dessin _p = [
  [
    (.12, 0),
    (.1, 1),
    (.12, .1),
    (.45, 0),
    (.78, .12),
    (.76, .38),
    (.45, .5),
    (.12, .42),
  ],
];
const _Dessin _p2 = [
  [(.1, 0), (.12, 1)],
  [(.12, .08), (.45, 0), (.78, .12), (.76, .38), (.45, .5), (.12, .42)],
];
const _Dessin _m = [
  [
    (.05, .02),
    (.07, 1),
    (.1, .3),
    (.27, 0),
    (.42, .12),
    (.46, 1),
    (.48, .3),
    (.66, 0),
    (.84, .12),
    (.9, 1),
  ],
];
const _Dessin _w = [
  [(0, 0), (.24, .98), (.5, .3), (.76, .98), (1, 0)],
];
const _Dessin _h = [
  [(.15, 0), (.16, 1), (.18, .58), (.42, .42), (.66, .52), (.7, 1)],
];
const _Dessin _r = [
  [(.12, 0), (.12, 1), (.13, .42), (.32, .1), (.58, 0), (.75, .06)],
];
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

/// Un Σ d'un trait, à points espacés comme le stylet les donne.
List<Trait> _sigma(double x, double y, double l, double h) => [
  Trait.depuisDocument({
    'points': [
      for (final (a, b) in const [
        (1.0, .05),
        (0.0, 0.0),
        (.55, .5),
        (0.0, 1.0),
        (1.0, .98),
      ])
        [x + a * l, y + b * h, 0.5],
    ],
  }),
];
const _Dessin _k = [
  [(.15, 0), (.15, 1)],
];

/// Pied de ligne à 100 ; un chiffre fait 40 de haut, une minuscule basse 22.
List<Trait> _haut(_Dessin d, double x, [double l = 26]) =>
    _signe(d, x, 60, l, 40);
List<Trait> _bas(_Dessin d, double x, [double l = 22]) =>
    _signe(d, x, 78, l, 22);

/// Une minuscule à jambage : son ventre sur la ligne, sa queue dessous.
List<Trait> _jambe(_Dessin d, double x) => _signe(d, x, 78, 30, 36);
List<Trait> _paren(_Dessin d, double x) => _signe(d, x, 56, 12, 48);

/// Un `i` : un bâton bas et son point au-dessus.
List<Trait> _i(double x) => [
  ..._signe(_baton, x, 80, 4, 20),
  ..._signe(_point, x - 2, 66, 6, 6),
];

/// `nom(x)` : les lettres du nom à partir de x = 0, puis `(x)`.
List<Trait> _fonction(List<List<Trait>> lettres, double fin) => _ligne([
  ...lettres,
  _paren(_ouvrante, fin + 6),
  _bas(_croix, fin + 24),
  _paren(_fermante, fin + 52),
]);

List<Trait> _sin() => _fonction([_bas(_s, 0), _i(30), _bas(_n, 42)], 64);

List<Trait> _jsonVersTraits(List<dynamic> traits) => [
  for (final t in traits)
    Trait.depuisDocument({
      'points': [
        for (final p in t as List<dynamic>) [(p as List)[0], p[1], 0.5],
      ],
    }),
];

class _Modele extends Lecteur {
  new(this.lectures);
  final Map<int, String> lectures;
  @override
  Future<String> lire(List<Trait> traits) async =>
      lectures[traits.length] ?? r'\varLambda';
}

void main() {
  group('minuscules lues au tracé (ADR 0046)', () {
    test('s, o, w, r, m, h : chacune reconnue', () {
      for (final (dessin, lettre, signe) in [
        (_s, 's', _bas(_s, 0)),
        (_o, 'o', _bas(_o, 0)),
        (_w, 'w', _bas(_w, 0, 30)),
        (_r, 'r', _bas(_r, 0, 16)),
        (_m, 'm', _bas(_m, 0, 32)),
        (_h, 'h', _haut(_h, 0, 40)),
      ]) {
        expect(dessin, isNotEmpty);
        expect(
          reconnaitreSigne(_dessin(signe))?.keys,
          contains(lettre),
          reason: lettre,
        );
      }
    });

    test('5 ou s, 0 ou o : à la hauteur d’un chiffre de la ligne', () {
      expect(
        lireAuTrace(_ligne([_haut(_un, 0), _haut(_plus, 32), _haut(_s, 64)])),
        '1+5',
      );
      expect(
        lireAuTrace(_ligne([_haut(_un, 0), _haut(_plus, 32), _bas(_o, 64)])),
        '1+o',
      );
      expect(
        lireAuTrace(_ligne([_haut(_un, 0), _haut(_plus, 32), _bas(_s, 64)])),
        '1+s',
      );
      // Collé à un chiffre, même petit, un `0` reste un chiffre : le `0`
      // d'Antsa, dans `30`, n'a que les deux tiers de la hauteur du `3`.
      expect(lireAuTrace(_ligne([_haut(_un, 0), _bas(_o, 30)])), '10');
    });

    test('9 ou g : le jambage descend sous la ligne', () {
      // `g(x)` : la queue du `g` passe sous le pied du `x`.
      expect(
        lireAuTrace(
          _ligne([
            _jambe(_g, 0),
            _paren(_ouvrante, 28),
            _bas(_croix, 46),
            _paren(_fermante, 74),
          ]),
        ),
        'g(x)',
      );
      // Posé sur la ligne, à côté d'un chiffre : un `9`.
      expect(
        lireAuTrace(_ligne([_haut(_un, 0), _signe(_g, 30, 60, 26, 40)])),
        '19',
      );
    });

    test('p : il descend ; posé sur la ligne, ce n’est pas un p', () {
      // En deux traits, le `p` est proche d'un `F` : lu juste, ou au modèle.
      expect(
        lireAuTrace(_ligne([_jambe(_p2, 0), _haut(_plus, 34), _haut(_un, 66)])),
        anyOf('p+1', isNull),
      );
      expect(
        lireAuTrace(_ligne([_jambe(_p, 0), _haut(_plus, 30), _haut(_un, 62)])),
        'p+1',
      );
      expect(
        lireAuTrace(_ligne([_haut(_p, 0), _haut(_plus, 34), _haut(_un, 66)])),
        isNot('p+1'),
      );
    });

    test('une minuscule à jambage sans ligne pour la situer : au modèle', () {
      expect(lireAuTrace(_ligne([_jambe(_g, 0), _haut(_egal, 30)])), isNull);
    });

    test('les signes d’Antsa (CC0) : h, o, p, q, r, w, k, 9', () {
      final json = jsonDecode(
        File('test/fixtures/antsa_signes.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final attendus = {
        'h': ['h'],
        'o': ['o'],
        'p': ['p'],
        'r': ['r'],
        'w': ['w'],
        'k': ['k'],
        '9': ['9'],
      };
      for (final e in (json['signes'] as List).cast<Map<String, dynamic>>()) {
        final attendu = e['attendu'] as String;
        final traits = [
          for (final t in _jsonVersTraits(e['traits'] as List))
            if (cadreDuGroupe([t]).width >= 5 || cadreDuGroupe([t]).height >= 5)
              t,
        ];
        final lu = reconnaitreSigne(_dessin(traits));
        // Le `q` d'Antsa est presque un bâton : seul, il se lit `1` (voir le
        // test suivant, où sa queue sous la ligne l'envoie au modèle).
        if (attendu == 'q') continue;
        // Jamais faux : lu juste (seul ou parmi ses jumeaux), ou le doute.
        if (lu != null) {
          expect(lu.keys, contains(attendu), reason: attendu);
        }
        if (attendus.containsKey(attendu) && attendu != '9') {
          // Ces minuscules-là se lisent (2 `h` sur 3 au moins, voir plus bas).
          if (attendu != 'h') expect(lu, isNotNull, reason: attendu);
        }
      }
      final h = [
        for (final e in (json['signes'] as List).cast<Map<String, dynamic>>())
          if (e['attendu'] == 'h')
            reconnaitreSigne(_dessin(_jsonVersTraits(e['traits'] as List))),
      ];
      expect(h.where((l) => l != null && l.containsKey('h')), hasLength(2));
    });
  });

  test('le q d’Antsa dans une ligne : sous la ligne, au modèle', () {
    final json = jsonDecode(
      File('test/fixtures/antsa_signes.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final e = (json['signes'] as List).cast<Map<String, dynamic>>().firstWhere(
      (e) => e['attendu'] == 'q',
    );
    final q = _jsonVersTraits(e['traits'] as List);
    final c = cadreDuGroupe(q);
    // Son ventre fait le quart du haut : la ligne passe dessous.
    final pied = c.top + 0.3 * c.height;
    final h = 0.5 * c.height;
    final ligne = [
      ...q,
      ..._signe(_plus, c.right + 8, pied - 0.8 * h, 0.8 * h, 0.8 * h),
      ..._signe(_un, c.right + 16 + 0.8 * h, pied - h, 0.4 * h, h),
    ];
    expect(lireAuTrace(ligne), anyOf('q+1', isNull));
  });

  group('noms de fonction lus au tracé (ADR 0046)', () {
    test(r'\sin(x)', () {
      expect(lireAuTrace(_sin()), r'\sin(x)');
    });

    test(r'\cos(x), \tan(x), \exp(x)', () {
      expect(
        lireAuTrace(_fonction([_bas(_c, 0), _bas(_o, 26), _bas(_s, 52)], 76)),
        r'\cos(x)',
      );
      expect(
        lireAuTrace(
          _fonction([_haut(_t, 0, 22), _bas(_a, 26), _bas(_n, 54)], 78),
        ),
        r'\tan(x)',
      );
      expect(
        lireAuTrace(
          _fonction([_bas(_e, 0), _bas(_croix, 26), _jambe(_p, 54)], 78),
        ),
        r'\exp(x)',
      );
    });

    test(r'\ln 2 et \log(x) : le l est un bâton haut', () {
      expect(
        lireAuTrace(
          _ligne([
            _signe(_baton, 0, 60, 4, 40),
            _bas(_n, 10),
            _haut(_deux, 40, 32),
          ]),
        ),
        r'\ln 2',
      );
      expect(
        lireAuTrace(
          _fonction([
            _signe(_baton, 0, 60, 4, 40),
            _bas(_o, 10),
            _jambe(_g, 38),
          ], 62),
        ),
        r'\log(x)',
      );
    });

    test(r'\det(A) : d, e, t', () {
      final lu = lireAuTrace(
        _fonction([_haut(_d, 0, 22), _bas(_e, 28), _haut(_t, 54, 22)], 78),
      );
      expect(lu, anyOf(r'\det(x)', isNull));
    });

    test('un nom sans argument, ou mal formé : au modèle', () {
      // `sin` seul, `sin =` : rien à calculer, le modèle verra.
      expect(lireAuTrace(_ligne([_bas(_s, 0), _i(30), _bas(_n, 42)])), isNull);
      expect(
        lireAuTrace(
          _ligne([_bas(_s, 0), _i(30), _bas(_n, 42), _haut(_egal, 72)]),
        ),
        isNull,
      );
      // `sn(x)` : pas de `i`, pas de mot ; trois lettres de suite non plus.
      final sn = lireAuTrace(_fonction([_bas(_s, 0), _bas(_n, 28)], 50));
      expect(sn, isNot(contains(r'\sin')));
    });

    test('le point du i : sans lui, pas de sin', () {
      final sansPoint = _fonction([
        _bas(_s, 0),
        _signe(_baton, 30, 80, 4, 20),
        _bas(_n, 42),
      ], 64);
      expect(lireAuTrace(sansPoint), isNot(r'\sin(x)'));
    });

    test('les signes lus : le nom est un seul signe', () {
      final lu = lireAuTraceDetaille(_sin());
      expect(lu?.signes.first.$2, r'\sin');
    });
  });

  group('k = 1 sous un Σ (ADR 0046, TODO § 0)', () {
    // `k` en deux traits (la hampe, puis le bras qui la touche), un `=`
    // serré contre lui, puis `1` ; `7` au-dessus ; `k` à droite.
    List<Trait> somme({double serre = 0}) => _ligne([
      _sigma(0, 20, 50, 50),
      _signe(_trois, 14, -16, 18, 26),
      // k : hampe de 70 à 96, bras de 82 à 96 qui part de la hampe.
      _signe(_k, -4, 70, 20, 26),
      _signe(
        const [
          [(.6, 0), (.05, .5), (.65, 1)],
        ],
        -1,
        80,
        14,
        16,
      ),
      // `=` serré : son bord gauche touche le bras du `k`.
      _signe(_egal, 12 - serre, 82, 12, 10),
      _signe(_un, 28, 72, 12, 24),
      // Le corps : un `k`.
      _signe(_k, 70, 30, 20, 30),
      _signe(
        const [
          [(.6, 0), (.05, .5), (.65, 1)],
        ],
        73,
        42,
        14,
        18,
      ),
    ]);

    test('la borne se lit k = 1, même serrée', () async {
      for (final serre in [0.0, 2.0, 4.0]) {
        final traits = somme(serre: serre);
        expect(trouverStructure(traits), isA<StructureSomme>());
        final lu = await lireStructure(_Modele({2: 'k'}), traits);
        expect(lu, r'\sum_{k=1}^{3} k', reason: 'serré de $serre');
      }
    });

    test('le k en deux traits reste un signe, au tracé aussi', () {
      final k = [
        ..._signe(_k, 0, 60, 20, 40),
        ..._signe(
          const [
            [(.6, 0), (.05, .5), (.65, 1)],
          ],
          3,
          76,
          18,
          24,
        ),
      ];
      expect(signesDeLaLigne(k), hasLength(1));
      final ligne = _ligne([k, _signe(_egal, 26, 78, 16, 10), _haut(_un, 48)]);
      final lu = lireAuTrace(ligne);
      // Juste, ou le modèle ; jamais `L=1-L`.
      expect(lu, anyOf('k=1', isNull));
    });

    test('un exposant collé à un 1 ne s’y accroche pas', () {
      final un = _haut(_baton, 0, 6);
      final deux = _signe(_trois, 4, 52, 12, 16);
      expect(accrocheAUneHampe(deux.single, un), isFalse);
    });
  });
}
