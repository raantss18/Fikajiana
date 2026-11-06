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

  test('sauvegarde : même figure, et nouveaux objets sans collision', () {
    final (a, b) = (libre(0, 0), libre(4, 0));
    final m = f.ajouter(_c(GenreConstruction.milieu, [a, b]));
    final relue = Figure.depuisJson(f.versJson());
    expect(relue.calculer()[m], _point(2, 0));
    expect(relue.ajouter(PointLibre(1, 1)), greaterThan(m));
  });
}
