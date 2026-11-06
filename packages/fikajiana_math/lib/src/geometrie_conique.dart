part of 'geometrie.dart';

/// Les coniques non dégénérées.
enum GenreConique {
  /// Une ellipse, cercle compris.
  ellipse,

  /// Une hyperbole.
  hyperbole,

  /// Une parabole.
  parabole,
}

/// La conique `A x² + B x y + C y² + D x + E y + F = 0`, et sa forme réduite.
///
/// Dans le repère de ses axes, tourné de [angle] :
/// - ellipse : X = a cos u, Y = b sin u ;
/// - hyperbole : X = a / cos u, Y = b tan u, les deux branches pour u dans
///   ]-π ; π] ;
/// - parabole : Y = u, X du second degré en u.
class ConiqueGeo extends FormeGeo {
  new _(
    this.genre,
    this.coefficients, {
    required this.centre,
    required this.angle,
    required this.demiA,
    required this.demiB,
    this._p2 = 0,
    this._p1 = 0,
    this._p0 = 0,
  });

  /// La conique de ces coefficients, `null` si elle est vide ou dégénérée.
  static ConiqueGeo? depuis(List<double> coefficients) {
    final norme = math.sqrt(
      coefficients.take(3).fold(0.0, (s, x) => s + x * x),
    );
    if (norme < _epsilon) return null;
    final k = coefficients.map((x) => x / norme).toList();
    final (a, b, c, d, e, f) = (k[0], k[1], k[2], k[3], k[4], k[5]);
    var angle = 0.5 * math.atan2(b, a - c);

    double l1De(double t) {
      final (co, si) = (math.cos(t), math.sin(t));
      return a * co * co + b * co * si + c * si * si;
    }

    double l2De(double t) {
      final (co, si) = (math.cos(t), math.sin(t));
      return a * si * si - b * co * si + c * co * co;
    }

    // Parabole : la valeur propre nulle va sur l'axe X.
    if (l2De(angle).abs() < 1e-9) angle += math.pi / 2;
    final (l1, l2) = (l1De(angle), l2De(angle));
    final (co, si) = (math.cos(angle), math.sin(angle));
    final (dr, er) = (d * co + e * si, -d * si + e * co);

    if (l1.abs() < 1e-9) {
      if (dr.abs() < 1e-9) return null;
      final (p2, p1, p0) = (l2 / dr, er / dr, f / dr);
      final u0 = -p1 / (2 * p2);
      final x0 = -(p2 * u0 * u0 + p1 * u0 + p0);
      return ConiqueGeo._(
        GenreConique.parabole,
        k,
        centre: PointGeo(co * x0 - si * u0, si * x0 + co * u0),
        angle: angle,
        demiA: 0,
        demiB: 0,
        p2: p2,
        p1: p1,
        p0: p0,
      );
    }

    final (x0, y0) = (-dr / (2 * l1), -er / (2 * l2));
    final g = f + dr * x0 / 2 + er * y0 / 2;
    if (g.abs() < 1e-11) return null;
    final centre = PointGeo(co * x0 - si * y0, si * x0 + co * y0);
    final (a2, b2) = (-g / l1, -g / l2);
    if (a2 < 0 && b2 < 0) return null;
    if (a2 > 0 && b2 > 0) {
      return ConiqueGeo._(
        GenreConique.ellipse,
        k,
        centre: centre,
        angle: angle,
        demiA: math.sqrt(a2),
        demiB: math.sqrt(b2),
      );
    }
    // Hyperbole : l'axe X porte ses sommets.
    final (reel, imaginaire, tourne) = a2 > 0
        ? (a2, -b2, angle)
        : (b2, -a2, angle + math.pi / 2);
    return ConiqueGeo._(
      GenreConique.hyperbole,
      k,
      centre: centre,
      angle: tourne,
      demiA: math.sqrt(reel),
      demiB: math.sqrt(imaginaire),
    );
  }

  /// La conique par cinq points, `null` s'il y en a plusieurs ou si elle
  /// dégénère, par exemple en deux droites.
  static ConiqueGeo? parCinqPoints(List<PointGeo> points) {
    final m = [
      for (final p in points) [p.x * p.x, p.x * p.y, p.y * p.y, p.x, p.y, 1.0],
    ];
    // L'élimination, avec pivot : le noyau de cette matrice 5×6.
    final pivots = <int>[];
    var ligne = 0;
    for (var colonne = 0; colonne < 6 && ligne < m.length; colonne++) {
      var meilleur = ligne;
      for (var i = ligne + 1; i < m.length; i++) {
        if (m[i][colonne].abs() > m[meilleur][colonne].abs()) meilleur = i;
      }
      if (m[meilleur][colonne].abs() < 1e-9) continue;
      final echange = m[ligne];
      m[ligne] = m[meilleur];
      m[meilleur] = echange;
      for (var i = 0; i < m.length; i++) {
        if (i == ligne) continue;
        final facteur = m[i][colonne] / m[ligne][colonne];
        for (var j = colonne; j < 6; j++) {
          m[i][j] -= facteur * m[ligne][j];
        }
      }
      pivots.add(colonne);
      ligne++;
    }
    if (pivots.length < 5) return null;
    final libre = {0, 1, 2, 3, 4, 5}.difference(pivots.toSet()).single;
    final x = List<double>.filled(6, 0);
    x[libre] = 1;
    for (var i = 0; i < 5; i++) {
      x[pivots[i]] = -m[i][libre] / m[i][pivots[i]];
    }
    return depuis(x);
  }

  static ConiqueGeo? _ellipse(PointGeo f1, PointGeo f2, PointGeo p) {
    final grand = (p.distance(f1) + p.distance(f2)) / 2;
    final focale = f1.distance(f2) / 2;
    final b2 = grand * grand - focale * focale;
    if (b2 < 1e-12) return null;
    return _canonique(f1, f2, grand * grand, b2);
  }

  static ConiqueGeo? _hyperbole(PointGeo f1, PointGeo f2, PointGeo p) {
    final reel = (p.distance(f1) - p.distance(f2)).abs() / 2;
    final focale = f1.distance(f2) / 2;
    final b2 = focale * focale - reel * reel;
    if (reel < 1e-9 || b2 < 1e-12) return null;
    return _canonique(f1, f2, reel * reel, -b2);
  }

  /// `X²/a2 + Y²/b2 = 1` dans le repère des foyers.
  static ConiqueGeo? _canonique(
    PointGeo f1,
    PointGeo f2,
    double a2,
    double b2,
  ) {
    final (cx, cy) = ((f1.x + f2.x) / 2, (f1.y + f2.y) / 2);
    final t = f1.distance(f2) < _epsilon
        ? 0.0
        : math.atan2(f2.y - f1.y, f2.x - f1.x);
    final (co, si) = (math.cos(t), math.sin(t));
    // X = co (x - cx) + si (y - cy) ; Y = -si (x - cx) + co (y - cy).
    final (p, q) = (1 / a2, 1 / b2);
    final a = p * co * co + q * si * si;
    final b = 2 * (p - q) * co * si;
    final c = p * si * si + q * co * co;
    return depuis([
      a,
      b,
      c,
      -2 * a * cx - b * cy,
      -b * cx - 2 * c * cy,
      a * cx * cx + b * cx * cy + c * cy * cy - 1,
    ]);
  }

  static ConiqueGeo? _parabole(PointGeo foyer, DroiteGeo d) {
    if ((d.a * foyer.x + d.b * foyer.y - d.c).abs() < 1e-9) return null;
    // (x - fx)² + (y - fy)² = (a x + b y - c)², avec a² + b² = 1.
    return depuis([
      1 - d.a * d.a,
      -2 * d.a * d.b,
      1 - d.b * d.b,
      -2 * foyer.x + 2 * d.a * d.c,
      -2 * foyer.y + 2 * d.b * d.c,
      foyer.x * foyer.x + foyer.y * foyer.y - d.c * d.c,
    ]);
  }

  static ConiqueGeo _duCercle(CercleGeo c) => depuis([
    1,
    0,
    1,
    -2 * c.centre.x,
    -2 * c.centre.y,
    c.centre.x * c.centre.x + c.centre.y * c.centre.y - c.rayon * c.rayon,
  ])!;

  /// Ellipse, hyperbole ou parabole.
  final GenreConique genre;

  /// A, B, C, D, E, F, avec A² + B² + C² = 1.
  final List<double> coefficients;

  /// Le centre ; pour une parabole, son sommet.
  final PointGeo centre;

  /// L'angle de l'axe X sur l'axe des abscisses.
  final double angle;

  /// Demi-axe a.
  final double demiA;

  /// Demi-axe b.
  final double demiB;

  final double _p2;
  final double _p1;
  final double _p0;

  /// La valeur de `A x² + B x y + C y² + D x + E y + F`, nulle sur la conique.
  double evaluer(double x, double y) {
    final k = coefficients;
    return k[0] * x * x +
        k[1] * x * y +
        k[2] * y * y +
        k[3] * x +
        k[4] * y +
        k[5];
  }

  /// Les valeurs utiles du paramètre.
  (double, double) get plage => genre == GenreConique.parabole
      ? (-_p1 / (2 * _p2) - 40, -_p1 / (2 * _p2) + 40)
      : (-math.pi, math.pi);

  /// Le point de paramètre [u].
  PointGeo point(double u) {
    final (x, y) = switch (genre) {
      GenreConique.ellipse => (demiA * math.cos(u), demiB * math.sin(u)),
      GenreConique.hyperbole => (demiA / math.cos(u), demiB * math.tan(u)),
      GenreConique.parabole => (-(_p2 * u * u + _p1 * u + _p0), u),
    };
    final (co, si) = (math.cos(angle), math.sin(angle));
    if (genre == GenreConique.parabole) {
      return PointGeo(co * x - si * y, si * x + co * y);
    }
    return PointGeo(centre.x + co * x - si * y, centre.y + si * x + co * y);
  }

  /// Le paramètre du point de la conique le plus proche de ([x], [y]).
  double parametreDe(double x, double y) {
    final (debut, fin) = plage;
    const pas = 256;
    var meilleur = debut;
    var distance = double.infinity;
    final cible = PointGeo(x, y);
    for (var i = 0; i < pas; i++) {
      final u = debut + (fin - debut) * i / pas;
      final d = point(u).distance(cible);
      if (d < distance) {
        distance = d;
        meilleur = u;
      }
    }
    // Section dorée autour du meilleur échantillon.
    final largeur = (fin - debut) / pas;
    var (a, b) = (meilleur - largeur, meilleur + largeur);
    const nombreOr = 0.618033988749895;
    for (var i = 0; i < 40; i++) {
      final c = b - nombreOr * (b - a);
      final d = a + nombreOr * (b - a);
      if (point(c).distance(cible) < point(d).distance(cible)) {
        b = d;
      } else {
        a = c;
      }
    }
    return (a + b) / 2;
  }

  /// De quoi la dessiner sans sortir de [portee] autour de son centre.
  List<List<PointGeo>> traces(double portee) {
    switch (genre) {
      case GenreConique.ellipse:
        return [
          [
            for (var i = 0; i <= 180; i++)
              point(-math.pi + 2 * math.pi * i / 180),
          ],
        ];
      case GenreConique.hyperbole:
        final limite = _arcCosinusHyperbolique(math.max(1.5, portee / demiA));
        final (co, si) = (math.cos(angle), math.sin(angle));
        return [
          for (final signe in const [1, -1])
            [
              for (var i = 0; i <= 120; i++)
                () {
                  final s = -limite + 2 * limite * i / 120;
                  final x = signe * demiA * _cosh(s);
                  final y = demiB * _sinh(s);
                  return PointGeo(
                    centre.x + co * x - si * y,
                    centre.y + si * x + co * y,
                  );
                }(),
            ],
        ];
      case GenreConique.parabole:
        final milieu = -_p1 / (2 * _p2);
        final demi = math.max(portee, math.sqrt(portee / _p2.abs()));
        return [
          [
            for (var i = 0; i <= 200; i++)
              point(milieu - demi + 2 * demi * i / 200),
          ],
        ];
    }
  }

  List<PointGeo> _cinqPoints() {
    final (debut, fin) = genre == GenreConique.parabole
        ? (-_p1 / (2 * _p2) - 2, -_p1 / (2 * _p2) + 2)
        : (-1.3, 1.3);
    return [for (var i = 0; i < 5; i++) point(debut + (fin - debut) * i / 4)];
  }

  List<PointGeo> _avecDroite(DroiteGeo d) {
    // M(t) = O + t v, reporté dans l'équation : un trinôme en t.
    final (ox, oy) = (d.a * d.c, d.b * d.c);
    final (vx, vy) = (d.b, -d.a);
    final k = coefficients;
    final a = k[0] * vx * vx + k[1] * vx * vy + k[2] * vy * vy;
    final b =
        2 * k[0] * ox * vx +
        k[1] * (ox * vy + oy * vx) +
        2 * k[2] * oy * vy +
        k[3] * vx +
        k[4] * vy;
    final c = evaluer(ox, oy);
    PointGeo m(double t) => PointGeo(ox + t * vx, oy + t * vy);
    if (a.abs() < 1e-11) {
      return b.abs() < 1e-11 ? const [] : [m(-c / b)];
    }
    final delta = b * b - 4 * a * c;
    if (delta < -1e-11) return const [];
    if (delta.abs() <= 1e-11) return [m(-b / (2 * a))];
    final r = math.sqrt(delta);
    return [m((-b - r) / (2 * a)), m((-b + r) / (2 * a))];
  }

  /// Au numérique : on parcourt la conique, de préférence la bornée, et on
  /// cherche où l'équation de l'autre change de signe. Un contact tangent, sans
  /// changement de signe, n'est pas vu.
  List<PointGeo> _avecConique(ConiqueGeo autre) {
    final (
      parcourue,
      equation,
    ) = genre != GenreConique.ellipse && autre.genre == GenreConique.ellipse
        ? (autre, this)
        : (this, autre);
    final (debut, fin) = parcourue.plage;
    const pas = 2048;
    final points = <PointGeo>[];
    double valeur(double u) {
      final p = parcourue.point(u);
      return equation.evaluer(p.x, p.y);
    }

    var (u, v) = (debut, valeur(debut));
    for (var i = 1; i <= pas; i++) {
      final suivant = debut + (fin - debut) * i / pas;
      final w = valeur(suivant);
      final asymptote =
          parcourue.genre == GenreConique.hyperbole &&
          math.cos(u) * math.cos(suivant) <= 0;
      if (v * w < 0 && !asymptote && v.isFinite && w.isFinite) {
        var (a, b, fa) = (u, suivant, v);
        for (var j = 0; j < 60; j++) {
          final m = (a + b) / 2;
          final fm = valeur(m);
          if (fa * fm <= 0) {
            b = m;
          } else {
            (a, fa) = (m, fm);
          }
        }
        points.add(parcourue.point((a + b) / 2));
      }
      (u, v) = (suivant, w);
    }
    return points;
  }

  /// La polaire de [p] : la droite qui joint les points de contact des
  /// tangentes menées par [p]. `null` en son centre.
  DroiteGeo? _polaire(PointGeo p) {
    final k = coefficients;
    final a = k[0] * p.x + k[1] * p.y / 2 + k[3] / 2;
    final b = k[1] * p.x / 2 + k[2] * p.y + k[4] / 2;
    final c = -(k[3] * p.x / 2 + k[4] * p.y / 2 + k[5]);
    final n = math.sqrt(a * a + b * b);
    if (n < _epsilon) return null;
    return DroiteGeo(a / n, b / n, c / n);
  }
}

double _cosh(double x) => (math.exp(x) + math.exp(-x)) / 2;
double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;
double _arcCosinusHyperbolique(double x) => math.log(x + math.sqrt(x * x - 1));

DroiteGeo? _tangente(FormeGeo courbe, FormeGeo point, int indice) {
  final k = switch (courbe) {
    final CercleGeo c => ConiqueGeo._duCercle(c),
    final ConiqueGeo k => k,
    _ => null,
  };
  if (k == null || point is! PointGeo) return null;
  final polaire = k._polaire(point);
  if (polaire == null) return null;
  // Sur la courbe, sa polaire est la tangente, et il n'y en a qu'une.
  if (k.evaluer(point.x, point.y).abs() < 1e-9) {
    return indice == 0 ? polaire : null;
  }
  final contacts = k._avecDroite(polaire);
  if (indice >= contacts.length) return null;
  return DroiteGeo.par(point, contacts[indice]);
}
