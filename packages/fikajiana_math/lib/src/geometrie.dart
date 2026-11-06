import 'dart:math' as math;

const double _epsilon = 1e-9;

/// Ce que vaut un objet une fois la figure calculée.
sealed class FormeGeo {
  const new();
}

/// Un point.
class PointGeo extends FormeGeo {
  /// Crée un point.
  const new(this.x, this.y);

  /// Abscisse.
  final double x;

  /// Ordonnée.
  final double y;

  /// Distance à [autre].
  double distance(PointGeo autre) =>
      math.sqrt(math.pow(x - autre.x, 2) + math.pow(y - autre.y, 2));
}

/// Une droite `a x + b y = c`, avec `a² + b² = 1`.
///
/// Un segment garde ses extrémités [debut] et [fin].
class DroiteGeo extends FormeGeo {
  /// Crée une droite ; (a, b) est déjà normé.
  const new(this.a, this.b, this.c, {this.debut, this.fin});

  /// Passant par [p] et [q], `null` s'ils sont confondus.
  static DroiteGeo? par(PointGeo p, PointGeo q, {bool segment = false}) {
    final (dx, dy) = (q.x - p.x, q.y - p.y);
    final n = math.sqrt(dx * dx + dy * dy);
    if (n < _epsilon) return null;
    final (a, b) = (-dy / n, dx / n);
    return DroiteGeo(
      a,
      b,
      a * p.x + b * p.y,
      debut: segment ? p : null,
      fin: segment ? q : null,
    );
  }

  /// Coefficient de x.
  final double a;

  /// Coefficient de y.
  final double b;

  /// Second membre.
  final double c;

  /// Première extrémité d'un segment.
  final PointGeo? debut;

  /// Seconde extrémité d'un segment.
  final PointGeo? fin;

  /// Est-ce un segment ?
  bool get estSegment => debut != null;

  /// [p], déjà sur la droite, est-il aussi sur le segment ?
  bool contient(PointGeo p) {
    final (d, f) = (debut, fin);
    if (d == null || f == null) return true;
    final longueur = d.distance(f);
    return p.distance(d) <= longueur + _epsilon &&
        p.distance(f) <= longueur + _epsilon;
  }
}

/// Un cercle.
class CercleGeo extends FormeGeo {
  /// Crée un cercle.
  const new(this.centre, this.rayon);

  /// Centre.
  final PointGeo centre;

  /// Rayon.
  final double rayon;
}

/// Comment un objet se construit.
sealed class Definition {
  const new();

  /// Les objets dont celui-ci dépend.
  List<int> get parents;

  /// La forme, ou `null` si la construction n'existe pas dans cette position,
  /// comme l'intersection de deux droites devenues parallèles.
  FormeGeo? calculer(FormeGeo? Function(int) valeur);

  /// Pour la sauvegarde.
  Map<String, dynamic> versJson();
}

/// Un point qu'on déplace au doigt.
class PointLibre extends Definition {
  /// Crée un point libre.
  new(this.x, this.y);

  /// Abscisse.
  double x;

  /// Ordonnée.
  double y;

  @override
  List<int> get parents => const [];

  @override
  FormeGeo calculer(FormeGeo? Function(int) valeur) => PointGeo(x, y);

  @override
  Map<String, dynamic> versJson() => {'t': 'libre', 'x': x, 'y': y};
}

/// Une construction nommée, à partir d'autres objets.
class Construite extends Definition {
  /// Crée une construction [genre] sur [parents].
  const new(this.genre, this.parents);

  /// La construction.
  final GenreConstruction genre;

  @override
  final List<int> parents;

  @override
  FormeGeo? calculer(FormeGeo? Function(int) valeur) {
    final formes = parents.map(valeur).toList();
    if (formes.contains(null)) return null;
    return genre._calculer(formes.cast<FormeGeo>());
  }

  @override
  Map<String, dynamic> versJson() => {'t': genre.name, 'p': parents};
}

/// Les constructions à la règle et au compas.
enum GenreConstruction {
  /// Milieu de deux points.
  milieu,

  /// Droite par deux points.
  droite,

  /// Segment entre deux points.
  segment,

  /// Cercle de centre le premier point, passant par le second.
  cercle,

  /// Parallèle à une droite par un point.
  parallele,

  /// Perpendiculaire à une droite par un point.
  perpendiculaire,

  /// Médiatrice de deux points.
  mediatrice,

  /// Bissectrice de l'angle en le deuxième de trois points.
  bissectrice,

  /// Premier point d'intersection de deux objets.
  intersection1,

  /// Second point d'intersection de deux objets.
  intersection2;

  FormeGeo? _calculer(List<FormeGeo> f) {
    PointGeo p(int i) => f[i] as PointGeo;
    DroiteGeo d(int i) => f[i] as DroiteGeo;
    return switch (this) {
      milieu => PointGeo((p(0).x + p(1).x) / 2, (p(0).y + p(1).y) / 2),
      droite => DroiteGeo.par(p(0), p(1)),
      segment => DroiteGeo.par(p(0), p(1), segment: true),
      cercle => CercleGeo(p(0), p(0).distance(p(1))),
      parallele => DroiteGeo(d(0).a, d(0).b, d(0).a * p(1).x + d(0).b * p(1).y),
      perpendiculaire => DroiteGeo(
        -d(0).b,
        d(0).a,
        -d(0).b * p(1).x + d(0).a * p(1).y,
      ),
      mediatrice => _mediatrice(p(0), p(1)),
      bissectrice => _bissectrice(p(0), p(1), p(2)),
      intersection1 => _intersection(f[0], f[1], 0),
      intersection2 => _intersection(f[0], f[1], 1),
    };
  }
}

DroiteGeo? _mediatrice(PointGeo p, PointGeo q) {
  final (dx, dy) = (q.x - p.x, q.y - p.y);
  final n = math.sqrt(dx * dx + dy * dy);
  if (n < _epsilon) return null;
  final (a, b) = (dx / n, dy / n);
  return DroiteGeo(a, b, a * (p.x + q.x) / 2 + b * (p.y + q.y) / 2);
}

DroiteGeo? _bissectrice(PointGeo p, PointGeo sommet, PointGeo q) {
  final (l1, l2) = (sommet.distance(p), sommet.distance(q));
  if (l1 < _epsilon || l2 < _epsilon) return null;
  final (ux, uy) = ((p.x - sommet.x) / l1, (p.y - sommet.y) / l1);
  final (vx, vy) = ((q.x - sommet.x) / l2, (q.y - sommet.y) / l2);
  var (dx, dy) = (ux + vx, uy + vy);
  // Un angle plat : la bissectrice est perpendiculaire à ses côtés.
  if (math.sqrt(dx * dx + dy * dy) < _epsilon) (dx, dy) = (-uy, ux);
  return DroiteGeo.par(sommet, PointGeo(sommet.x + dx, sommet.y + dy));
}

PointGeo? _intersection(FormeGeo a, FormeGeo b, int indice) {
  final points = switch ((a, b)) {
    (final DroiteGeo d, final DroiteGeo e) => _droiteDroite(d, e),
    (final DroiteGeo d, final CercleGeo c) => _droiteCercle(d, c),
    (final CercleGeo c, final DroiteGeo d) => _droiteCercle(d, c),
    (final CercleGeo c, final CercleGeo e) => _cercleCercle(c, e),
    _ => const <PointGeo>[],
  };
  final surLesDeux = points.where((p) {
    return (a is! DroiteGeo || a.contient(p)) &&
        (b is! DroiteGeo || b.contient(p));
  }).toList();
  return indice < surLesDeux.length ? surLesDeux[indice] : null;
}

List<PointGeo> _droiteDroite(DroiteGeo d, DroiteGeo e) {
  final det = d.a * e.b - d.b * e.a;
  if (det.abs() < _epsilon) return const [];
  return [
    PointGeo((d.c * e.b - d.b * e.c) / det, (d.a * e.c - d.c * e.a) / det),
  ];
}

List<PointGeo> _droiteCercle(DroiteGeo d, CercleGeo c) {
  final distance = d.c - (d.a * c.centre.x + d.b * c.centre.y);
  final reste = c.rayon * c.rayon - distance * distance;
  if (reste < -_epsilon) return const [];
  final pied = PointGeo(
    c.centre.x + d.a * distance,
    c.centre.y + d.b * distance,
  );
  if (reste.abs() <= _epsilon) return [pied];
  final h = math.sqrt(reste);
  return [
    PointGeo(pied.x - d.b * h, pied.y + d.a * h),
    PointGeo(pied.x + d.b * h, pied.y - d.a * h),
  ];
}

List<PointGeo> _cercleCercle(CercleGeo c, CercleGeo e) {
  final (dx, dy) = (e.centre.x - c.centre.x, e.centre.y - c.centre.y);
  final distance = math.sqrt(dx * dx + dy * dy);
  if (distance < _epsilon) return const [];
  final a =
      (distance * distance + c.rayon * c.rayon - e.rayon * e.rayon) /
      (2 * distance);
  final reste = c.rayon * c.rayon - a * a;
  if (reste < -_epsilon) return const [];
  final (ux, uy) = (dx / distance, dy / distance);
  final pied = PointGeo(c.centre.x + a * ux, c.centre.y + a * uy);
  if (reste.abs() <= _epsilon) return [pied];
  final h = math.sqrt(reste);
  return [
    PointGeo(pied.x - uy * h, pied.y + ux * h),
    PointGeo(pied.x + uy * h, pied.y - ux * h),
  ];
}

/// Une figure dynamique : déplacer un point libre recalcule tout ce qui en
/// dépend. Un objet ne dépend que d'objets créés avant lui.
class Figure {
  final _definitions = <int, Definition>{};
  var _prochain = 0;

  /// Les objets, dans l'ordre de construction.
  Iterable<int> get objets => _definitions.keys;

  /// La définition de [id].
  Definition definition(int id) => _definitions[id]!;

  /// Ajoute un objet et rend son identifiant.
  int ajouter(Definition definition) {
    for (final parent in definition.parents) {
      if (!_definitions.containsKey(parent)) {
        throw ArgumentError('parent inconnu : $parent');
      }
    }
    _definitions[_prochain] = definition;
    return _prochain++;
  }

  /// Toutes les formes ; `null` pour un objet qui n'existe pas dans cette
  /// position.
  Map<int, FormeGeo?> calculer() {
    final valeurs = <int, FormeGeo?>{};
    _definitions.forEach((id, definition) {
      valeurs[id] = definition.calculer((parent) => valeurs[parent]);
    });
    return valeurs;
  }

  /// Déplace le point libre [id].
  void deplacer(int id, double x, double y) {
    final point = _definitions[id];
    if (point is! PointLibre) throw ArgumentError('$id n’est pas libre');
    point
      ..x = x
      ..y = y;
  }

  /// Retire [id] et tout ce qui en dépend.
  void retirer(int id) {
    final partis = {id};
    for (final MapEntry(:key, :value) in _definitions.entries) {
      if (value.parents.any(partis.contains)) partis.add(key);
    }
    partis.forEach(_definitions.remove);
  }

  /// Pour la sauvegarde.
  List<Map<String, dynamic>> versJson() => [
    for (final MapEntry(:key, :value) in _definitions.entries)
      {'id': key, ...value.versJson()},
  ];

  /// Relit une sauvegarde.
  static Figure depuisJson(List<dynamic> json) {
    final figure = Figure();
    for (final objet in json.cast<Map<String, dynamic>>()) {
      final id = objet['id'] as int;
      final genre = objet['t'] as String;
      figure._definitions[id] = genre == 'libre'
          ? PointLibre(
              (objet['x'] as num).toDouble(),
              (objet['y'] as num).toDouble(),
            )
          : Construite(
              GenreConstruction.values.byName(genre),
              (objet['p'] as List<dynamic>).cast<int>(),
            );
      figure._prochain = math.max(figure._prochain, id + 1);
    }
    return figure;
  }
}
