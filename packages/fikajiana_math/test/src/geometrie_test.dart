import 'dart:math' as math;

import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:test/test.dart';

Matcher _point(double x, double y) => isA<PointGeo>()
    .having((p) => p.x, 'x', closeTo(x, 1e-9))
    .having((p) => p.y, 'y', closeTo(y, 1e-9));

Construite _c(GenreConstruction genre, List<int> parents) =>
    Construite(genre, parents);

void main() {
  late Figure f;
  setUp(() => f = Figure());

  int libre(double x, double y) => f.ajouter(PointLibre(x, y));

  test('milieu', () {
    final m = f.ajouter(
      _c(GenreConstruction.milieu, [libre(0, 0), libre(4, 2)]),
    );
    expect(f.calculer()[m], _point(2, 1));
  });

  test('deux droites se coupent', () {
    final d = f.ajouter(
      _c(GenreConstruction.droite, [libre(0, 0), libre(1, 1)]),
    );
    final e = f.ajouter(
      _c(GenreConstruction.droite, [libre(0, 2), libre(2, 0)]),
    );
    final i = f.ajouter(_c(GenreConstruction.intersection1, [d, e]));
    expect(f.calculer()[i], _point(1, 1));
  });

  test('parallèles : pas d’intersection, sans erreur', () {
    final a = libre(0, 0);
    final d = f.ajouter(_c(GenreConstruction.droite, [a, libre(1, 0)]));
    final p = f.ajouter(_c(GenreConstruction.parallele, [d, libre(0, 3)]));
    final i = f.ajouter(_c(GenreConstruction.intersection1, [d, p]));
    expect(f.calculer()[i], isNull);
  });

  test('perpendiculaire par un point', () {
    final d = f.ajouter(
      _c(GenreConstruction.droite, [libre(0, 0), libre(1, 0)]),
    );
    final p = f.ajouter(
      _c(GenreConstruction.perpendiculaire, [d, libre(2, 5)]),
    );
    final i = f.ajouter(_c(GenreConstruction.intersection1, [d, p]));
    expect(f.calculer()[i], _point(2, 0));
  });

  test('médiatrice : à égale distance des deux points', () {
    final (a, b) = (libre(1, 1), libre(5, 3));
    final m = f.ajouter(_c(GenreConstruction.mediatrice, [a, b]));
    final d = f.ajouter(
      _c(GenreConstruction.droite, [libre(0, 10), libre(1, 9)]),
    );
    final i = f.ajouter(_c(GenreConstruction.intersection1, [m, d]));
    final v = f.calculer();
    final (pa, pb, pi) = (
      v[a]! as PointGeo,
      v[b]! as PointGeo,
      v[i]! as PointGeo,
    );
    expect(pi.distance(pa), closeTo(pi.distance(pb), 1e-9));
  });

  test('bissectrice d’un angle droit : la diagonale', () {
    final b = f.ajouter(
      _c(GenreConstruction.bissectrice, [
        libre(1, 0),
        libre(0, 0),
        libre(0, 1),
      ]),
    );
    final d = f.calculer()[b]! as DroiteGeo;
    expect(d.a.abs(), closeTo(math.sqrt1_2, 1e-9));
    expect(d.b.abs(), closeTo(math.sqrt1_2, 1e-9));
    expect(d.c, closeTo(0, 1e-9));
  });

  test('un cercle coupe une droite en deux points', () {
    final c = f.ajouter(
      _c(GenreConstruction.cercle, [libre(0, 0), libre(5, 0)]),
    );
    final d = f.ajouter(
      _c(GenreConstruction.droite, [libre(-9, 3), libre(9, 3)]),
    );
    final i = f.ajouter(_c(GenreConstruction.intersection1, [c, d]));
    final j = f.ajouter(_c(GenreConstruction.intersection2, [c, d]));
    final v = f.calculer();
    final xs = {(v[i]! as PointGeo).x.round(), (v[j]! as PointGeo).x.round()};
    expect(xs, {-4, 4});
    expect((v[i]! as PointGeo).y, closeTo(3, 1e-9));
  });

  test('deux cercles : triangle équilatéral', () {
    final (a, b) = (libre(0, 0), libre(2, 0));
    final c = f.ajouter(_c(GenreConstruction.cercle, [a, b]));
    final e = f.ajouter(_c(GenreConstruction.cercle, [b, a]));
    final i = f.ajouter(_c(GenreConstruction.intersection1, [c, e]));
    expect(f.calculer()[i], _point(1, math.sqrt(3)));
  });

  test('cercles disjoints : pas d’intersection', () {
    final c = f.ajouter(
      _c(GenreConstruction.cercle, [libre(0, 0), libre(1, 0)]),
    );
    final e = f.ajouter(
      _c(GenreConstruction.cercle, [libre(9, 0), libre(10, 0)]),
    );
    final i = f.ajouter(_c(GenreConstruction.intersection1, [c, e]));
    expect(f.calculer()[i], isNull);
  });

  test('un segment ne coupe pas au-delà de ses extrémités', () {
    final s = f.ajouter(
      _c(GenreConstruction.segment, [libre(0, 0), libre(1, 0)]),
    );
    final d = f.ajouter(
      _c(GenreConstruction.droite, [libre(5, -1), libre(5, 1)]),
    );
    final i = f.ajouter(_c(GenreConstruction.intersection1, [s, d]));
    expect(f.calculer()[i], isNull);
  });

  group('dynamique', () {
    test('déplacer un point recalcule ce qui en dépend', () {
      final a = libre(0, 0);
      final m = f.ajouter(_c(GenreConstruction.milieu, [a, libre(4, 0)]));
      expect(f.calculer()[m], _point(2, 0));
      f.deplacer(a, 2, 2);
      expect(f.calculer()[m], _point(3, 1));
    });

    test('une construction impossible puis possible revient', () {
      final (a, b) = (libre(0, 0), libre(0, 0));
      final d = f.ajouter(_c(GenreConstruction.droite, [a, b]));
      final m = f.ajouter(
        _c(GenreConstruction.perpendiculaire, [d, libre(1, 1)]),
      );
      expect(f.calculer()[d], isNull);
      expect(f.calculer()[m], isNull);
      f.deplacer(b, 1, 0);
      expect(f.calculer()[d], isNotNull);
      expect(f.calculer()[m], isNotNull);
    });

    test('seul un point libre se déplace', () {
      final m = f.ajouter(
        _c(GenreConstruction.milieu, [libre(0, 0), libre(1, 0)]),
      );
      expect(() => f.deplacer(m, 0, 0), throwsArgumentError);
    });

    test('retirer un objet retire ce qui en dépend, en cascade', () {
      final (a, b) = (libre(0, 0), libre(1, 0));
      final d = f.ajouter(_c(GenreConstruction.droite, [a, b]));
      final p = f.ajouter(_c(GenreConstruction.parallele, [d, libre(0, 1)]));
      f.retirer(a);
      expect(f.objets, isNot(contains(d)));
      expect(f.objets, isNot(contains(p)));
      expect(f.objets, contains(b));
    });

    test('un parent inconnu est refusé', () {
      expect(
        () => f.ajouter(_c(GenreConstruction.milieu, [41, 42])),
        throwsArgumentError,
      );
    });
  });

  // Valeurs de référence relevées avec SymPy 1.14 (sympy.geometry), 2026-11-06.
  group('références SymPy', () {
    test('cercle circonscrit de (0,0), (4,0), (0,3)', () {
      final c = f.ajouter(
        _c(GenreConstruction.cercleTroisPoints, [
          libre(0, 0),
          libre(4, 0),
          libre(0, 3),
        ]),
      );
      final cercle = f.calculer()[c]! as CercleGeo;
      expect(cercle.centre, _point(2, 1.5));
      expect(cercle.rayon, closeTo(2.5, 1e-9));
    });

    test('tangentes à x²+y²=9 par (5,0)', () {
      final (o, p) = (libre(0, 0), libre(3, 0));
      final c = f.ajouter(_c(GenreConstruction.cercle, [o, p]));
      final q = libre(5, 0);
      final t1 = f.ajouter(_c(GenreConstruction.tangente1, [c, q]));
      final t2 = f.ajouter(_c(GenreConstruction.tangente2, [c, q]));
      final v = f.calculer();
      // SymPy : 12x/5 ∓ 16y/5 = 12, soit 3x ∓ 4y = 15, normée par 5.
      final pentes = {
        for (final t in [t1, t2])
          ((v[t]! as DroiteGeo).a / (v[t]! as DroiteGeo).b).toStringAsFixed(6),
      };
      expect(pentes, {'0.750000', '-0.750000'});
    });

    test('tangente en un point du cercle : une seule', () {
      final c = f.ajouter(
        _c(GenreConstruction.cercle, [libre(0, 0), libre(3, 0)]),
      );
      final q = libre(3, 0);
      final t1 = f.ajouter(_c(GenreConstruction.tangente1, [c, q]));
      final t2 = f.ajouter(_c(GenreConstruction.tangente2, [c, q]));
      final v = f.calculer();
      expect((v[t1]! as DroiteGeo).a.abs(), closeTo(1, 1e-9));
      expect(v[t2], isNull);
    });

    test('ellipse de foyers (±3,0) par (5,0), coupée par y=2', () {
      final e = f.ajouter(
        _c(GenreConstruction.ellipse, [libre(-3, 0), libre(3, 0), libre(5, 0)]),
      );
      final k = f.calculer()[e]! as ConiqueGeo;
      expect(k.genre, GenreConique.ellipse);
      expect({k.demiA.round(), k.demiB.round()}, {4, 5});
      expect(k.demiA * k.demiB, closeTo(20, 1e-9));
      final d = DroiteGeo.par(const PointGeo(0, 2), const PointGeo(1, 2))!;
      final xs = intersections(k, d).map((p) => p.x).toList()..sort();
      expect(xs[0], closeTo(-5 * math.sqrt(3) / 2, 1e-9));
      expect(xs[1], closeTo(5 * math.sqrt(3) / 2, 1e-9));
    });

    test('hyperbole de foyers (±5,0) par (3,0), coupée par y=4', () {
      final e = f.ajouter(
        _c(GenreConstruction.hyperbole, [
          libre(-5, 0),
          libre(5, 0),
          libre(3, 0),
        ]),
      );
      final k = f.calculer()[e]! as ConiqueGeo;
      expect(k.genre, GenreConique.hyperbole);
      expect(k.demiA, closeTo(3, 1e-9));
      expect(k.demiB, closeTo(4, 1e-9));
      final d = DroiteGeo.par(const PointGeo(0, 4), const PointGeo(1, 4))!;
      final xs = intersections(k, d).map((p) => p.x).toList()..sort();
      expect(xs[0], closeTo(-3 * math.sqrt(2), 1e-9));
      expect(xs[1], closeTo(3 * math.sqrt(2), 1e-9));
    });

    test('parabole de foyer (0,1), directrice y=-1, coupée par y=x', () {
      final d = f.ajouter(
        _c(GenreConstruction.droite, [libre(0, -1), libre(1, -1)]),
      );
      final e = f.ajouter(_c(GenreConstruction.parabole, [libre(0, 1), d]));
      final k = f.calculer()[e]! as ConiqueGeo;
      expect(k.genre, GenreConique.parabole);
      expect(k.centre, _point(0, 0));
      final y = DroiteGeo.par(const PointGeo(0, 0), const PointGeo(1, 1))!;
      final xs = intersections(k, y).map((p) => p.x).toList()..sort();
      expect(xs[0], closeTo(0, 1e-9));
      expect(xs[1], closeTo(4, 1e-9));
    });

    test('conique par cinq points : x²/4 + y² = 1', () {
      final e = f.ajouter(
        _c(GenreConstruction.coniqueCinqPoints, [
          libre(2, 0),
          libre(-2, 0),
          libre(0, 1),
          libre(0, -1),
          libre(math.sqrt(3), 0.5),
        ]),
      );
      final k = f.calculer()[e]! as ConiqueGeo;
      expect(k.genre, GenreConique.ellipse);
      expect(
        {k.demiA.toStringAsFixed(6), k.demiB.toStringAsFixed(6)},
        {'2.000000', '1.000000'},
      );
    });

    test('cinq points dont quatre alignés : pas de conique', () {
      final e = f.ajouter(
        _c(GenreConstruction.coniqueCinqPoints, [
          libre(0, 0),
          libre(1, 0),
          libre(2, 0),
          libre(3, 0),
          libre(0, 1),
        ]),
      );
      expect(f.calculer()[e], isNull);
    });

    test('x²+y²=4 et x²/9+y²=1 : quatre points', () {
      const c = CercleGeo(PointGeo(0, 0), 2);
      final k = ConiqueGeo.depuis([1 / 9, 0, 1, 0, 0, -1])!;
      final points = intersections(k, c);
      expect(points, hasLength(4));
      for (final p in points) {
        expect(p.x.abs(), closeTo(1.83711730708738, 1e-7));
        expect(p.y.abs(), closeTo(0.790569415042095, 1e-7));
      }
    });

    test('rotation de (2,1) autour de (1,1), 90°', () {
      final n = f.ajouter(NombreLibre(90));
      final r = f.ajouter(
        _c(GenreConstruction.rotation, [libre(2, 1), libre(1, 1), n]),
      );
      expect(f.calculer()[r], _point(1, 2));
    });

    test('symétrique de (3,0) par y=x', () {
      final d = f.ajouter(
        _c(GenreConstruction.droite, [libre(0, 0), libre(1, 1)]),
      );
      final s = f.ajouter(
        _c(GenreConstruction.symetrieAxiale, [libre(3, 0), d]),
      );
      // Projeté (3/2, 3/2) selon SymPy : l'image est son symétrique.
      expect(f.calculer()[s], _point(0, 3));
    });

    test('aire du triangle (0,0), (4,0), (4,3) ; hexagone de côté 2', () {
      final (a, b, c) = (libre(0, 0), libre(4, 0), libre(4, 3));
      final t = f.ajouter(_c(GenreConstruction.polygone, [a, b, c]));
      final at = f.ajouter(_c(GenreConstruction.aire, [t]));
      final h = f.ajouter(
        Construite(GenreConstruction.polygoneRegulier, [
          libre(0, 0),
          libre(2, 0),
        ], parametre: 6),
      );
      final ah = f.ajouter(_c(GenreConstruction.aire, [h]));
      final v = f.calculer();
      expect((v[at]! as NombreGeo).valeur, closeTo(6, 1e-9));
      expect((v[ah]! as NombreGeo).valeur, closeTo(10.3923048454133, 1e-9));
    });

    test('angle de (1,0), (0,0), (1,1) : 45°', () {
      final g = f.ajouter(
        _c(GenreConstruction.angle, [libre(1, 0), libre(0, 0), libre(1, 1)]),
      );
      expect((f.calculer()[g]! as NombreGeo).valeur, closeTo(45, 1e-9));
    });
  });

  group('lignes', () {
    test('une demi-droite ne coupe que de son côté', () {
      final s = f.ajouter(
        _c(GenreConstruction.demiDroite, [libre(0, 0), libre(1, 0)]),
      );
      final d1 = f.ajouter(
        _c(GenreConstruction.droite, [libre(3, -1), libre(3, 1)]),
      );
      final d2 = f.ajouter(
        _c(GenreConstruction.droite, [libre(-3, -1), libre(-3, 1)]),
      );
      final i1 = f.ajouter(_c(GenreConstruction.intersection1, [s, d1]));
      final i2 = f.ajouter(_c(GenreConstruction.intersection1, [s, d2]));
      final v = f.calculer();
      expect(v[i1], _point(3, 0));
      expect(v[i2], isNull);
    });

    test('translation par un vecteur', () {
      final u = f.ajouter(
        _c(GenreConstruction.vecteur, [libre(1, 1), libre(3, 2)]),
      );
      final t = f.ajouter(_c(GenreConstruction.translation, [libre(0, 0), u]));
      expect(f.calculer()[t], _point(2, 1));
    });

    test('pente : 1/2, et pas de pente pour une verticale', () {
      final d = f.ajouter(
        _c(GenreConstruction.droite, [libre(0, 0), libre(2, 1)]),
      );
      final v = f.ajouter(
        _c(GenreConstruction.droite, [libre(0, 0), libre(0, 1)]),
      );
      final (pd, pv) = (
        f.ajouter(_c(GenreConstruction.pente, [d])),
        f.ajouter(_c(GenreConstruction.pente, [v])),
      );
      final r = f.calculer();
      expect((r[pd]! as NombreGeo).valeur, closeTo(0.5, 1e-9));
      expect(r[pv], isNull);
    });

    test('distance d’un point à une droite', () {
      final d = f.ajouter(
        _c(GenreConstruction.droite, [libre(0, 0), libre(1, 0)]),
      );
      final n = f.ajouter(_c(GenreConstruction.distance, [libre(4, 3), d]));
      expect((f.calculer()[n]! as NombreGeo).valeur, closeTo(3, 1e-9));
    });
  });

  group('cercles et arcs', () {
    test('arc : ne coupe que sur son ouverture', () {
      final g = f.ajouter(
        _c(GenreConstruction.arc, [libre(0, 0), libre(2, 0), libre(0, 2)]),
      );
      final d = f.ajouter(
        _c(GenreConstruction.droite, [libre(-5, 1), libre(5, 1)]),
      );
      final i1 = f.ajouter(_c(GenreConstruction.intersection1, [g, d]));
      final i2 = f.ajouter(_c(GenreConstruction.intersection2, [g, d]));
      final v = f.calculer();
      expect(v[i1], _point(math.sqrt(3), 1));
      expect(v[i2], isNull);
    });

    test('arc par trois points : passe par celui du milieu', () {
      final g = f.ajouter(
        _c(GenreConstruction.arcTroisPoints, [
          libre(2, 0),
          libre(-2, 0),
          libre(0, 2),
        ]),
      );
      final c = f.calculer()[g]! as CercleGeo;
      expect(c.contient(const PointGeo(-2, 0)), isTrue);
      expect(c.contient(const PointGeo(0, -2)), isTrue);
      expect(c.contient(const PointGeo(math.sqrt2, math.sqrt2)), isFalse);
    });

    test('demi-cercle de diamètre deux points', () {
      final g = f.ajouter(
        _c(GenreConstruction.demiCercle, [libre(-2, 0), libre(2, 0)]),
      );
      final c = f.calculer()[g]! as CercleGeo;
      expect(c.rayon, closeTo(2, 1e-9));
      expect(c.balayage, closeTo(math.pi, 1e-9));
    });

    test('cercle de rayon un curseur : suit, et un rayon négatif l’efface', () {
      final r = f.ajouter(NombreLibre(2));
      final c = f.ajouter(_c(GenreConstruction.cercleRayon, [libre(0, 0), r]));
      expect((f.calculer()[c]! as CercleGeo).rayon, 2);
      f.fixerNombre(r, 3);
      expect((f.calculer()[c]! as CercleGeo).rayon, 3);
      f.fixerNombre(r, -1);
      expect(f.calculer()[c], isNull);
    });

    test('image d’un arc par une symétrie axiale : même ouverture', () {
      final g = f.ajouter(
        _c(GenreConstruction.arc, [libre(0, 0), libre(2, 0), libre(0, 2)]),
      );
      final d = f.ajouter(
        _c(GenreConstruction.droite, [libre(-5, 0), libre(5, 0)]),
      );
      final s = f.ajouter(_c(GenreConstruction.symetrieAxiale, [g, d]));
      final c = f.calculer()[s]! as CercleGeo;
      expect(c.contient(const PointGeo(math.sqrt2, -math.sqrt2)), isTrue);
      expect(c.contient(const PointGeo(math.sqrt2, math.sqrt2)), isFalse);
    });
  });

  group('polygones', () {
    test('polygone régulier : carré, tourné dans le sens direct', () {
      final g = f.ajouter(
        Construite(GenreConstruction.polygoneRegulier, [
          libre(0, 0),
          libre(2, 0),
        ], parametre: 4),
      );
      final s = f.ajouter(
        Construite(GenreConstruction.sommet, [g], parametre: 2),
      );
      expect(f.calculer()[s], _point(2, 2));
    });

    test('centre de gravité d’un triangle', () {
      final g = f.ajouter(
        _c(GenreConstruction.polygone, [libre(0, 0), libre(6, 0), libre(0, 3)]),
      );
      final c = f.ajouter(_c(GenreConstruction.centreGravite, [g]));
      expect(f.calculer()[c], _point(2, 1));
    });

    test('un polygone se coupe sur ses côtés', () {
      final g = f.ajouter(
        _c(GenreConstruction.polygone, [
          libre(0, 0),
          libre(4, 0),
          libre(4, 4),
          libre(0, 4),
        ]),
      );
      final d = f.ajouter(
        _c(GenreConstruction.droite, [libre(-1, 1), libre(5, 1)]),
      );
      final i = f.ajouter(_c(GenreConstruction.intersection1, [g, d]));
      final j = f.ajouter(_c(GenreConstruction.intersection2, [g, d]));
      final v = f.calculer();
      expect(
        {(v[i]! as PointGeo).x.round(), (v[j]! as PointGeo).x.round()},
        {0, 4},
      );
    });

    test('image d’un polygone par homothétie : aire multipliée par k²', () {
      final g = f.ajouter(
        _c(GenreConstruction.polygone, [libre(0, 0), libre(1, 0), libre(0, 1)]),
      );
      final k = f.ajouter(NombreLibre(3));
      final h = f.ajouter(
        _c(GenreConstruction.homothetie, [g, libre(0, 0), k]),
      );
      expect((f.calculer()[h]! as PolygoneGeo).aire, closeTo(4.5, 1e-9));
    });
  });

  group('point sur objet', () {
    test('sur une droite : glisse sans la quitter, suit quand elle bouge', () {
      final (a, b) = (libre(0, 0), libre(1, 0));
      final d = f.ajouter(_c(GenreConstruction.droite, [a, b]));
      final m = f.ajouter(PointSur(d, 2));
      f.deplacer(m, 5, 7);
      final p = f.calculer()[m]! as PointGeo;
      expect(p.x, closeTo(5, 1e-9));
      expect(p.y, closeTo(0, 1e-9));
      f.deplacer(b, 0, 1);
      final q = f.calculer()[m]! as PointGeo;
      expect(q.x, closeTo(0, 1e-9));
    });

    test('sur un segment : reste entre les extrémités', () {
      final d = f.ajouter(
        _c(GenreConstruction.segment, [libre(0, 0), libre(2, 0)]),
      );
      final m = f.ajouter(PointSur(d, 0.5));
      f.deplacer(m, 9, 1);
      expect(f.calculer()[m], _point(2, 0));
    });

    test('sur un cercle, un arc, un polygone, une conique', () {
      final c = f.ajouter(
        _c(GenreConstruction.cercle, [libre(0, 0), libre(2, 0)]),
      );
      final m = f.ajouter(PointSur(c, 0));
      f.deplacer(m, 0, 9);
      expect(f.calculer()[m], _point(0, 2));

      final g = f.ajouter(
        _c(GenreConstruction.polygone, [libre(0, 0), libre(4, 0), libre(4, 4)]),
      );
      final n = f.ajouter(PointSur(g, 0));
      f.deplacer(n, 5, 2);
      expect(f.calculer()[n], _point(4, 2));

      final e = f.ajouter(
        _c(GenreConstruction.ellipse, [libre(-3, 0), libre(3, 0), libre(5, 0)]),
      );
      final o = f.ajouter(PointSur(e, 0));
      f.deplacer(o, 0, 9);
      final p = f.calculer()[o]! as PointGeo;
      expect(p.x, closeTo(0, 1e-5));
      expect(p.y, closeTo(4, 1e-5));
    });
  });

  group('lieu', () {
    test('milieu de A fixe et M sur un cercle : un cercle de rayon r/2', () {
      final c = f.ajouter(
        _c(GenreConstruction.cercle, [libre(0, 0), libre(4, 0)]),
      );
      final m = f.ajouter(PointSur(c, 1));
      final a = libre(6, 0);
      final i = f.ajouter(_c(GenreConstruction.milieu, [a, m]));
      final l = f.ajouter(Lieu(i, m));
      final lieu = f.calculer()[l]! as LieuGeo;
      expect(lieu.morceaux, hasLength(1));
      for (final p in lieu.morceaux.single) {
        expect(p.distance(const PointGeo(3, 0)), closeTo(2, 1e-9));
      }
    });

    test('point qui ne dépend pas du moteur : pas de lieu', () {
      final c = f.ajouter(
        _c(GenreConstruction.cercle, [libre(0, 0), libre(4, 0)]),
      );
      final m = f.ajouter(PointSur(c, 1));
      final l = f.ajouter(Lieu(libre(9, 9), m));
      expect(f.calculer()[l], isNull);
    });
  });

  group('noms', () {
    test('dans l’ordre, et les droites d’après leurs points', () {
      final (a, b) = (libre(0, 0), libre(1, 0));
      final s = f.ajouter(_c(GenreConstruction.segment, [a, b]));
      final d = f.ajouter(_c(GenreConstruction.droite, [a, b]));
      final e = f.ajouter(_c(GenreConstruction.parallele, [d, libre(0, 1)]));
      expect(f.nom(a), 'A');
      expect(f.nom(b), 'B');
      expect(f.nom(s), '[AB]');
      expect(f.nom(d), '(AB)');
      expect(f.nom(e), 'd');
    });

    test('l’image de A s’appelle A′', () {
      final a = libre(0, 0);
      final s = f.ajouter(
        _c(GenreConstruction.symetrieCentrale, [a, libre(1, 0)]),
      );
      expect(f.nom(s), 'A′');
    });

    test('renommer : les noms dérivés suivent, un doublon est refusé', () {
      final (a, b) = (libre(0, 0), libre(1, 0));
      final s = f.ajouter(_c(GenreConstruction.segment, [a, b]));
      expect(f.renommer(a, 'O'), isTrue);
      expect(f.nom(s), '[OB]');
      expect(f.renommer(b, 'O'), isFalse);
      expect(f.renommer(b, '  '), isFalse);
    });
  });

  group('relations', () {
    test('une parallèle construite résiste à la déformation', () {
      final d = f.ajouter(
        _c(GenreConstruction.droite, [libre(0, 0), libre(1, 0)]),
      );
      final p = f.ajouter(_c(GenreConstruction.parallele, [d, libre(0, 3)]));
      final constats = f.constater(d, p);
      expect(constats.single.relation, RelationGeo.paralleles);
      expect(constats.single.resiste, isTrue);
    });

    test('des droites parallèles par hasard : vrai ici seulement', () {
      final d = f.ajouter(
        _c(GenreConstruction.droite, [libre(0, 0), libre(1, 0)]),
      );
      final e = f.ajouter(
        _c(GenreConstruction.droite, [libre(0, 2), libre(1, 2)]),
      );
      final constats = f.constater(d, e);
      expect(constats.single.relation, RelationGeo.paralleles);
      expect(constats.single.resiste, isFalse);
    });

    test('le constat ne déplace rien', () {
      final a = libre(1, 2);
      final d = f.ajouter(_c(GenreConstruction.droite, [a, libre(3, 4)]));
      f.constater(d, d);
      expect(f.calculer()[a], _point(1, 2));
    });

    test('le milieu est sur son segment et à égale distance', () {
      final (a, b) = (libre(0, 0), libre(4, 1));
      final s = f.ajouter(_c(GenreConstruction.segment, [a, b]));
      final m = f.ajouter(_c(GenreConstruction.milieu, [a, b]));
      final constats = f.constater(m, s);
      expect(constats.single.relation, RelationGeo.appartient);
      expect(constats.single.resiste, isTrue);
      final (s1, s2) = (
        f.ajouter(_c(GenreConstruction.segment, [a, m])),
        f.ajouter(_c(GenreConstruction.segment, [m, b])),
      );
      expect(
        f.constater(s1, s2).any((c) {
          return c.relation == RelationGeo.memeLongueur && c.resiste;
        }),
        isTrue,
      );
    });

    test('tangentes : droite et cercle ; deux cercles', () {
      final c = f.ajouter(
        _c(GenreConstruction.cercle, [libre(0, 0), libre(2, 0)]),
      );
      final q = libre(5, 1);
      final t = f.ajouter(_c(GenreConstruction.tangente1, [c, q]));
      expect(f.constater(t, c).single.relation, RelationGeo.tangents);
      expect(f.constater(t, c).single.resiste, isTrue);
      expect(
        relationsEntre(
          const CercleGeo(PointGeo(0, 0), 1),
          const CercleGeo(PointGeo(3, 0), 2),
        ),
        {RelationGeo.tangents},
      );
    });

    test('rien de vrai : aucun constat', () {
      final d = f.ajouter(
        _c(GenreConstruction.droite, [libre(0, 0), libre(1, 0)]),
      );
      final e = f.ajouter(
        _c(GenreConstruction.droite, [libre(0, 0), libre(1, 1)]),
      );
      expect(f.constater(d, e), isEmpty);
    });
  });

  test('glisser un objet d’un bloc déplace ses points libres', () {
    final (a, b) = (libre(0, 0), libre(1, 0));
    final s = f.ajouter(_c(GenreConstruction.segment, [a, b]));
    expect(f.estTranslatable(s), isTrue);
    f.translater(s, 2, 3);
    expect(f.calculer()[a], _point(2, 3));
    expect(f.calculer()[b], _point(3, 3));
    final m = f.ajouter(PointSur(s, 0.5));
    final d = f.ajouter(_c(GenreConstruction.droite, [a, m]));
    expect(f.estTranslatable(d), isFalse);
  });

  test('sauvegarde : même figure, et nouveaux objets sans collision', () {
    final (a, b) = (libre(0, 0), libre(4, 0));
    final m = f.ajouter(_c(GenreConstruction.milieu, [a, b]));
    final relue = Figure.depuisJson(f.versJson());
    expect(relue.calculer()[m], _point(2, 0));
    expect(relue.ajouter(PointLibre(1, 1)), greaterThan(m));
  });

  test('sauvegarde : tout genre et l’apparence sont relus', () {
    final (a, b) = (libre(0, 0), libre(4, 0));
    final c = f.ajouter(_c(GenreConstruction.cercle, [a, b]));
    final m = f.ajouter(PointSur(c, 1));
    final n = f.ajouter(NombreLibre(2, min: 0, max: 9));
    f
      ..ajouter(Lieu(m, m))
      ..ajouter(
        Construite(GenreConstruction.polygoneRegulier, [a, b], parametre: 5),
      );
    f.apparence(c)
      ..pointille = true
      ..couleur = 3
      ..visible = false
      ..nomVisible = false;
    f.renommer(a, 'O');
    final relue = Figure.depuisJson(f.versJson());
    expect(relue.nom(a), 'O');
    expect(relue.apparence(c).pointille, isTrue);
    expect(relue.apparence(c).couleur, 3);
    expect(relue.apparence(c).visible, isFalse);
    expect(relue.apparence(c).nomVisible, isFalse);
    expect((relue.definition(m) as PointSur).u, 1);
    expect((relue.definition(n) as NombreLibre).max, 9);
  });

  test('une figure sauvegardée sans noms en reçoit, dans l’ordre', () {
    final relue = Figure.depuisJson([
      {'id': 0, 't': 'libre', 'x': 0, 'y': 0},
      {'id': 1, 't': 'libre', 'x': 1, 'y': 0},
      {
        'id': 2,
        't': 'segment',
        'p': [0, 1],
      },
    ]);
    expect(relue.nom(1), 'B');
    expect(relue.nom(2), '[AB]');
  });
}
