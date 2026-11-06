import 'dart:math' as math;

part 'geometrie_conique.dart';
part 'geometrie_relations.dart';

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
/// Un segment garde ses extrémités [debut] et [fin] ; une demi-droite garde
/// seulement son origine [debut], et part dans le sens de ([b], -[a]).
class DroiteGeo extends FormeGeo {
  /// Crée une droite ; (a, b) est déjà normé.
  const new(
    this.a,
    this.b,
    this.c, {
    this.debut,
    this.fin,
    this.vecteur = false,
  });

  /// Passant par [p] et [q], `null` s'ils sont confondus.
  static DroiteGeo? par(
    PointGeo p,
    PointGeo q, {
    bool segment = false,
    bool demiDroite = false,
    bool vecteur = false,
  }) {
    final (dx, dy) = (q.x - p.x, q.y - p.y);
    final n = math.sqrt(dx * dx + dy * dy);
    if (n < _epsilon) return null;
    final (a, b) = (-dy / n, dx / n);
    return DroiteGeo(
      a,
      b,
      a * p.x + b * p.y,
      debut: segment || demiDroite || vecteur ? p : null,
      fin: segment || vecteur ? q : null,
      vecteur: vecteur,
    );
  }

  /// Coefficient de x.
  final double a;

  /// Coefficient de y.
  final double b;

  /// Second membre.
  final double c;

  /// Première extrémité d'un segment, origine d'une demi-droite.
  final PointGeo? debut;

  /// Seconde extrémité d'un segment.
  final PointGeo? fin;

  /// Un segment fléché de [debut] vers [fin].
  final bool vecteur;

  /// Est-ce un segment ?
  bool get estSegment => debut != null && fin != null;

  /// Est-ce une demi-droite ?
  bool get estDemiDroite => debut != null && fin == null;

  /// [p], déjà sur la droite, est-il aussi sur le segment ou la demi-droite ?
  bool contient(PointGeo p) {
    final (d, f) = (debut, fin);
    if (d == null) return true;
    if (f == null) {
      return (p.x - d.x) * b - (p.y - d.y) * a >= -_tolerance;
    }
    final longueur = d.distance(f);
    return p.distance(d) <= longueur + _tolerance &&
        p.distance(f) <= longueur + _tolerance;
  }
}

/// Une marge pour ce qui s'est accumulé dans les calculs.
const double _tolerance = 1e-9;

/// Un cercle, ou l'arc qui part de l'angle [depart] sur [balayage] radians,
/// dans le sens direct.
class CercleGeo extends FormeGeo {
  /// Crée un cercle.
  const new(this.centre, this.rayon, {this.depart, this.balayage});

  /// Centre.
  final PointGeo centre;

  /// Rayon.
  final double rayon;

  /// Angle de départ d'un arc.
  final double? depart;

  /// Ouverture d'un arc, positive.
  final double? balayage;

  /// Est-ce un arc ?
  bool get estArc => balayage != null;

  /// Le point d'angle [t].
  PointGeo point(double t) =>
      PointGeo(centre.x + rayon * math.cos(t), centre.y + rayon * math.sin(t));

  /// [p], déjà sur le cercle, est-il aussi sur l'arc ?
  bool contient(PointGeo p) {
    final (d, o) = (depart, balayage);
    if (d == null || o == null) return true;
    final angle = math.atan2(p.y - centre.y, p.x - centre.x);
    final ecart = (angle - d) % (2 * math.pi);
    return ecart <= o + 1e-7 || ecart >= 2 * math.pi - 1e-7;
  }
}

/// Un polygone.
class PolygoneGeo extends FormeGeo {
  /// Crée un polygone.
  const new(this.sommets);

  /// Les sommets, dans l'ordre.
  final List<PointGeo> sommets;

  /// Les côtés ; un côté de longueur nulle n'est pas compté.
  List<DroiteGeo> get cotes => [
    for (var i = 0; i < sommets.length; i++)
      ?DroiteGeo.par(
        sommets[i],
        sommets[(i + 1) % sommets.length],
        segment: true,
      ),
  ];

  /// Aire, par la formule du lacet : un polygone croisé n'a pas d'aire utile.
  double get aire {
    var somme = 0.0;
    for (var i = 0; i < sommets.length; i++) {
      final (p, q) = (sommets[i], sommets[(i + 1) % sommets.length]);
      somme += p.x * q.y - q.x * p.y;
    }
    return somme.abs() / 2;
  }

  /// Périmètre.
  double get perimetre {
    var somme = 0.0;
    for (var i = 0; i < sommets.length; i++) {
      somme += sommets[i].distance(sommets[(i + 1) % sommets.length]);
    }
    return somme;
  }

  /// Isobarycentre des sommets.
  PointGeo get centre {
    var (x, y) = (0.0, 0.0);
    for (final s in sommets) {
      x += s.x;
      y += s.y;
    }
    return PointGeo(x / sommets.length, y / sommets.length);
  }
}

/// Un nombre : curseur ou mesure.
class NombreGeo extends FormeGeo {
  /// Crée un nombre.
  const new(this.valeur);

  /// Sa valeur.
  final double valeur;
}

/// Un angle géométrique, en degrés, entre 0 et 180.
class AngleGeo extends NombreGeo {
  /// Crée un angle en [sommet], dont l'arc part de [depart] sur [balayage]
  /// radians dans le sens direct.
  const new(super.valeur, this.sommet, this.depart, this.balayage);

  /// Le sommet.
  final PointGeo sommet;

  /// Angle du côté d'où part la marque.
  final double depart;

  /// Ouverture de la marque.
  final double balayage;
}

/// Une courbe obtenue point par point : un lieu.
class LieuGeo extends FormeGeo {
  /// Crée un lieu.
  const new(this.morceaux);

  /// Les morceaux continus.
  final List<List<PointGeo>> morceaux;
}

/// La distance de ([x], [y]) à une forme, ou l'infini si elle n'a pas de sens.
double distanceA(FormeGeo? forme, double x, double y) {
  final p = PointGeo(x, y);
  return switch (forme) {
    final PointGeo q => q.distance(p),
    final DroiteGeo d => _distanceDroite(d, p),
    final CercleGeo c => _distanceCercle(c, p),
    final PolygoneGeo g =>
      g.cotes.isEmpty
          ? g.sommets.first.distance(p)
          : g.cotes.map((d) => _distanceDroite(d, p)).reduce(math.min),
    final ConiqueGeo k => k.point(k.parametreDe(x, y)).distance(p),
    final LieuGeo l => _distanceLieu(l, p),
    NombreGeo() || null => double.infinity,
  };
}

double _distanceDroite(DroiteGeo d, PointGeo p) {
  final ecart = d.a * p.x + d.b * p.y - d.c;
  final pied = PointGeo(p.x - d.a * ecart, p.y - d.b * ecart);
  if (d.contient(pied)) return ecart.abs();
  final (debut, fin) = (d.debut!, d.fin);
  return fin == null
      ? p.distance(debut)
      : math.min(p.distance(debut), p.distance(fin));
}

double _distanceCercle(CercleGeo c, PointGeo p) {
  final angle = math.atan2(p.y - c.centre.y, p.x - c.centre.x);
  if (c.contient(c.point(angle))) {
    return (c.centre.distance(p) - c.rayon).abs();
  }
  final fin = c.depart! + c.balayage!;
  return math.min(p.distance(c.point(c.depart!)), p.distance(c.point(fin)));
}

double _distanceLieu(LieuGeo l, PointGeo p) {
  var meilleure = double.infinity;
  for (final morceau in l.morceaux) {
    for (final q in morceau) {
      meilleure = math.min(meilleure, q.distance(p));
    }
  }
  return meilleure;
}

/// Le genre d'un objet : son nom automatique et ce qu'on peut en faire.
enum CategorieGeo {
  /// Un point.
  point,

  /// Droite, segment, demi-droite, vecteur.
  ligne,

  /// Cercle ou arc.
  cercle,

  /// Polygone.
  polygone,

  /// Ellipse, hyperbole, parabole.
  conique,

  /// Curseur ou mesure.
  nombre,

  /// Lieu.
  lieu,
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

/// Un point qui glisse sur un objet, sans pouvoir le quitter.
class PointSur extends Definition {
  /// Crée un point à la position [u] sur [support].
  new(this.support, this.u);

  /// L'objet qui le porte.
  final int support;

  /// Sa position : voir [pointSurForme].
  double u;

  @override
  List<int> get parents => [support];

  @override
  FormeGeo? calculer(FormeGeo? Function(int) valeur) {
    final forme = valeur(support);
    return forme == null ? null : pointSurForme(forme, u);
  }

  @override
  Map<String, dynamic> versJson() => {
    't': 'sur',
    'p': [support],
    'u': u,
  };
}

/// Le point de [forme] à la position [u] : abscisse sur une droite, angle sur
/// un cercle, rang de côté sur un polygone. `null` si elle ne porte pas de
/// point.
PointGeo? pointSurForme(FormeGeo forme, double u) {
  switch (forme) {
    case final DroiteGeo d:
      final (debut, fin) = (d.debut, d.fin);
      if (debut != null && fin != null) {
        final t = u.clamp(0.0, 1.0);
        return PointGeo(
          debut.x + t * (fin.x - debut.x),
          debut.y + t * (fin.y - debut.y),
        );
      }
      if (debut != null) {
        final t = math.max(0, u);
        return PointGeo(debut.x + t * d.b, debut.y - t * d.a);
      }
      return PointGeo(d.a * d.c + u * d.b, d.b * d.c - u * d.a);
    case final CercleGeo c:
      final (depart, balayage) = (c.depart, c.balayage);
      if (depart != null && balayage != null) {
        return c.point(depart + u.clamp(0.0, 1.0) * balayage);
      }
      return c.point(u);
    case final PolygoneGeo g:
      final n = g.sommets.length;
      final rang = (u % n).floor();
      final t = u % n - rang;
      final (p, q) = (g.sommets[rang], g.sommets[(rang + 1) % n]);
      return PointGeo(p.x + t * (q.x - p.x), p.y + t * (q.y - p.y));
    case final ConiqueGeo k:
      return k.point(u);
    case PointGeo() || NombreGeo() || LieuGeo():
      return null;
  }
}

/// La position sur [forme] du point le plus proche de ([x], [y]).
double parametreSurForme(FormeGeo forme, double x, double y) {
  switch (forme) {
    case final DroiteGeo d:
      final (debut, fin) = (d.debut, d.fin);
      if (debut != null && fin != null) {
        final (dx, dy) = (fin.x - debut.x, fin.y - debut.y);
        final t =
            ((x - debut.x) * dx + (y - debut.y) * dy) / (dx * dx + dy * dy);
        return t.clamp(0.0, 1.0);
      }
      if (debut != null) {
        return math.max(0, (x - debut.x) * d.b - (y - debut.y) * d.a);
      }
      return x * d.b - y * d.a;
    case final CercleGeo c:
      final angle = math.atan2(y - c.centre.y, x - c.centre.x);
      final (depart, balayage) = (c.depart, c.balayage);
      if (depart == null || balayage == null) return angle;
      // Hors de l'arc, on retient son bout le plus proche.
      final ecart = (angle - depart) % (2 * math.pi);
      if (ecart <= balayage) return ecart / balayage;
      return ecart - balayage < 2 * math.pi - ecart ? 1 : 0;
    case final PolygoneGeo g:
      var meilleur = 0.0;
      var distance = double.infinity;
      final n = g.sommets.length;
      for (var i = 0; i < n; i++) {
        final (p, q) = (g.sommets[i], g.sommets[(i + 1) % n]);
        final (dx, dy) = (q.x - p.x, q.y - p.y);
        final carre = dx * dx + dy * dy;
        final t = carre < _epsilon
            ? 0.0
            : (((x - p.x) * dx + (y - p.y) * dy) / carre).clamp(0.0, 1.0);
        final d = math.sqrt(
          math.pow(p.x + t * dx - x, 2) + math.pow(p.y + t * dy - y, 2),
        );
        if (d < distance) {
          distance = d;
          meilleur = i + t;
        }
      }
      return meilleur;
    case final ConiqueGeo k:
      return k.parametreDe(x, y);
    case PointGeo() || NombreGeo() || LieuGeo():
      return 0;
  }
}

/// Un nombre réglé au curseur.
class NombreLibre extends Definition {
  /// Crée un curseur.
  new(this.valeur, {double? min, double? max})
    : min = min ?? math.min(-5, valeur),
      max = max ?? math.max(5, valeur);

  /// Sa valeur.
  double valeur;

  /// Le bas du curseur.
  double min;

  /// Le haut du curseur.
  double max;

  @override
  List<int> get parents => const [];

  @override
  FormeGeo calculer(FormeGeo? Function(int) valeur) => NombreGeo(this.valeur);

  @override
  Map<String, dynamic> versJson() => {
    't': 'nombre',
    'v': valeur,
    'min': min,
    'max': max,
  };
}

/// Le lieu du point [trace] quand [moteur], un point sur objet, parcourt son
/// support. Calculé par la figure, qui seule peut rejouer ce qui en dépend.
class Lieu extends Definition {
  /// Crée un lieu.
  const new(this.trace, this.moteur);

  /// Le point dont on suit la trace.
  final int trace;

  /// Le point qui parcourt son support.
  final int moteur;

  @override
  List<int> get parents => [trace, moteur];

  @override
  FormeGeo? calculer(FormeGeo? Function(int) valeur) => null;

  @override
  Map<String, dynamic> versJson() => {
    't': 'lieu',
    'p': [trace, moteur],
  };
}

/// Une construction nommée, à partir d'autres objets.
class Construite extends Definition {
  /// Crée une construction [genre] sur [parents].
  const new(this.genre, this.parents, {this.parametre});

  /// La construction.
  final GenreConstruction genre;

  @override
  final List<int> parents;

  /// Pour un polygone régulier : le nombre de côtés ; pour un sommet : son
  /// rang.
  final int? parametre;

  @override
  FormeGeo? calculer(FormeGeo? Function(int) valeur) {
    final formes = parents.map(valeur).toList();
    if (formes.contains(null)) return null;
    return genre._calculer(formes.cast<FormeGeo>(), parametre);
  }

  @override
  Map<String, dynamic> versJson() => {
    't': genre.name,
    'p': parents,
    'k': ?parametre,
  };
}

/// Les constructions.
enum GenreConstruction {
  /// Milieu de deux points.
  milieu,

  /// Droite par deux points.
  droite,

  /// Segment entre deux points.
  segment,

  /// Demi-droite d'origine le premier point, passant par le second.
  demiDroite,

  /// Vecteur du premier point vers le second.
  vecteur,

  /// Cercle de centre le premier point, passant par le second.
  cercle,

  /// Cercle de centre un point, de rayon un nombre.
  cercleRayon,

  /// Cercle passant par trois points.
  cercleTroisPoints,

  /// Arc de centre le premier point, du deuxième vers le troisième.
  arc,

  /// Arc passant par trois points, le deuxième entre les deux autres.
  arcTroisPoints,

  /// Demi-cercle de diamètre deux points.
  demiCercle,

  /// Parallèle à une droite par un point.
  parallele,

  /// Perpendiculaire à une droite par un point.
  perpendiculaire,

  /// Médiatrice de deux points.
  mediatrice,

  /// Bissectrice de l'angle en le deuxième de trois points.
  bissectrice,

  /// Première tangente à un cercle ou une conique, par un point.
  tangente1,

  /// Seconde tangente à un cercle ou une conique, par un point.
  tangente2,

  /// Premier point d'intersection de deux objets.
  intersection1,

  /// Deuxième point d'intersection de deux objets.
  intersection2,

  /// Troisième point d'intersection de deux objets.
  intersection3,

  /// Quatrième point d'intersection de deux objets.
  intersection4,

  /// Centre d'un cercle, d'une ellipse ou d'une hyperbole.
  centre,

  /// Isobarycentre des sommets d'un polygone.
  centreGravite,

  /// Polygone par ses sommets.
  polygone,

  /// Polygone régulier de [Construite.parametre] côtés, sur un côté.
  polygoneRegulier,

  /// Le sommet de rang [Construite.parametre] d'un polygone.
  sommet,

  /// Ellipse de deux foyers, passant par un point.
  ellipse,

  /// Hyperbole de deux foyers, passant par un point.
  hyperbole,

  /// Parabole d'un foyer et d'une directrice.
  parabole,

  /// Conique par cinq points.
  coniqueCinqPoints,

  /// Image d'un objet par la symétrie de centre un point.
  symetrieCentrale,

  /// Image d'un objet par la symétrie d'axe une droite.
  symetrieAxiale,

  /// Image d'un objet par la translation d'un vecteur.
  translation,

  /// Image d'un objet par la rotation de centre un point et d'angle un nombre,
  /// en degrés, dans le sens direct.
  rotation,

  /// Image d'un objet par l'homothétie de centre un point et de rapport un
  /// nombre.
  homothetie,

  /// Longueur d'un segment, périmètre d'un cercle ou d'un polygone.
  longueur,

  /// Distance d'un point à un point ou à une droite.
  distance,

  /// Angle en le deuxième de trois points.
  angle,

  /// Aire d'un polygone, d'un cercle ou d'une ellipse.
  aire,

  /// Pente d'une droite.
  pente;

  /// Le genre du résultat ; `null` pour une image, du genre de l'original.
  CategorieGeo? get categorie => switch (this) {
    milieu ||
    intersection1 ||
    intersection2 ||
    intersection3 ||
    intersection4 ||
    centre ||
    centreGravite ||
    sommet => CategorieGeo.point,
    droite ||
    segment ||
    demiDroite ||
    vecteur ||
    parallele ||
    perpendiculaire ||
    mediatrice ||
    bissectrice ||
    tangente1 ||
    tangente2 => CategorieGeo.ligne,
    cercle ||
    cercleRayon ||
    cercleTroisPoints ||
    arc ||
    arcTroisPoints ||
    demiCercle => CategorieGeo.cercle,
    polygone || polygoneRegulier => CategorieGeo.polygone,
    ellipse ||
    hyperbole ||
    parabole ||
    coniqueCinqPoints => CategorieGeo.conique,
    longueur || distance || angle || aire || pente => CategorieGeo.nombre,
    symetrieCentrale ||
    symetrieAxiale ||
    translation ||
    rotation ||
    homothetie => null,
  };

  FormeGeo? _calculer(List<FormeGeo> f, int? parametre) {
    PointGeo p(int i) => f[i] as PointGeo;
    DroiteGeo d(int i) => f[i] as DroiteGeo;
    double n(int i) => (f[i] as NombreGeo).valeur;
    return switch (this) {
      milieu => PointGeo((p(0).x + p(1).x) / 2, (p(0).y + p(1).y) / 2),
      droite => DroiteGeo.par(p(0), p(1)),
      segment => DroiteGeo.par(p(0), p(1), segment: true),
      demiDroite => DroiteGeo.par(p(0), p(1), demiDroite: true),
      vecteur => DroiteGeo.par(p(0), p(1), vecteur: true),
      cercle => CercleGeo(p(0), p(0).distance(p(1))),
      cercleRayon => n(1) < 0 ? null : CercleGeo(p(0), n(1)),
      cercleTroisPoints => _cercleCirconscrit(p(0), p(1), p(2)),
      arc => _arc(p(0), p(1), p(2)),
      arcTroisPoints => _arcTroisPoints(p(0), p(1), p(2)),
      demiCercle => _arc(
        PointGeo((p(0).x + p(1).x) / 2, (p(0).y + p(1).y) / 2),
        p(0),
        p(1),
      ),
      parallele => DroiteGeo(d(0).a, d(0).b, d(0).a * p(1).x + d(0).b * p(1).y),
      perpendiculaire => DroiteGeo(
        -d(0).b,
        d(0).a,
        -d(0).b * p(1).x + d(0).a * p(1).y,
      ),
      mediatrice => _mediatrice(p(0), p(1)),
      bissectrice => _bissectrice(p(0), p(1), p(2)),
      tangente1 => _tangente(f[0], f[1], 0),
      tangente2 => _tangente(f[0], f[1], 1),
      intersection1 => _intersection(f[0], f[1], 0),
      intersection2 => _intersection(f[0], f[1], 1),
      intersection3 => _intersection(f[0], f[1], 2),
      intersection4 => _intersection(f[0], f[1], 3),
      centre => _centre(f[0]),
      centreGravite => (f[0] as PolygoneGeo).centre,
      polygone => PolygoneGeo(f.cast<PointGeo>()),
      polygoneRegulier => _polygoneRegulier(p(0), p(1), parametre!),
      sommet => (f[0] as PolygoneGeo).sommets[parametre!],
      ellipse => ConiqueGeo._ellipse(p(0), p(1), p(2)),
      hyperbole => ConiqueGeo._hyperbole(p(0), p(1), p(2)),
      parabole => ConiqueGeo._parabole(p(0), d(1)),
      coniqueCinqPoints => ConiqueGeo.parCinqPoints(f.cast<PointGeo>()),
      symetrieCentrale => _image(
        f[0],
        (q) => PointGeo(2 * p(1).x - q.x, 2 * p(1).y - q.y),
      ),
      symetrieAxiale => _image(f[0], (q) {
        final ecart = d(1).a * q.x + d(1).b * q.y - d(1).c;
        return PointGeo(q.x - 2 * d(1).a * ecart, q.y - 2 * d(1).b * ecart);
      }, directe: false),
      translation => _translation(f[0], d(1)),
      rotation => _rotation(f[0], p(1), n(2)),
      homothetie => _homothetie(f[0], p(1), n(2)),
      longueur => _longueur(f[0]),
      distance => NombreGeo(distanceA(f[1], p(0).x, p(0).y)),
      angle => _angle(p(0), p(1), p(2)),
      aire => _aire(f[0]),
      pente => d(0).b.abs() < _epsilon ? null : NombreGeo(-d(0).a / d(0).b),
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

CercleGeo? _cercleCirconscrit(PointGeo a, PointGeo b, PointGeo c) {
  final d = 2 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y));
  if (d.abs() < _epsilon) return null;
  final (a2, b2, c2) = (
    a.x * a.x + a.y * a.y,
    b.x * b.x + b.y * b.y,
    c.x * c.x + c.y * c.y,
  );
  final centre = PointGeo(
    (a2 * (b.y - c.y) + b2 * (c.y - a.y) + c2 * (a.y - b.y)) / d,
    (a2 * (c.x - b.x) + b2 * (a.x - c.x) + c2 * (b.x - a.x)) / d,
  );
  return CercleGeo(centre, centre.distance(a));
}

double _angleDe(PointGeo centre, PointGeo p) =>
    math.atan2(p.y - centre.y, p.x - centre.x);

CercleGeo? _arc(PointGeo centre, PointGeo debut, PointGeo fin) {
  final rayon = centre.distance(debut);
  if (rayon < _epsilon || centre.distance(fin) < _epsilon) return null;
  final depart = _angleDe(centre, debut);
  var balayage = (_angleDe(centre, fin) - depart) % (2 * math.pi);
  if (balayage < _epsilon) balayage = 2 * math.pi;
  return CercleGeo(centre, rayon, depart: depart, balayage: balayage);
}

CercleGeo? _arcTroisPoints(PointGeo a, PointGeo m, PointGeo b) {
  final cercle = _cercleCirconscrit(a, m, b);
  if (cercle == null) return null;
  final depart = _angleDe(cercle.centre, a);
  final versM = (_angleDe(cercle.centre, m) - depart) % (2 * math.pi);
  final versB = (_angleDe(cercle.centre, b) - depart) % (2 * math.pi);
  // M doit être sur l'arc : sinon, c'est l'arc de b vers a.
  return versM <= versB
      ? CercleGeo(cercle.centre, cercle.rayon, depart: depart, balayage: versB)
      : CercleGeo(
          cercle.centre,
          cercle.rayon,
          depart: _angleDe(cercle.centre, b),
          balayage: 2 * math.pi - versB,
        );
}

PolygoneGeo? _polygoneRegulier(PointGeo a, PointGeo b, int cotes) {
  if (a.distance(b) < _epsilon || cotes < 3) return null;
  // L'angle intérieur, compté vers l'intérieur pour tourner en sens direct.
  final angle = math.pi - 2 * math.pi / cotes;
  final sommets = [a, b];
  for (var i = 2; i < cotes; i++) {
    final (p, q) = (sommets[i - 2], sommets[i - 1]);
    final (dx, dy) = (p.x - q.x, p.y - q.y);
    // Le sommet suivant : le côté précédent tourne autour de son extrémité.
    sommets.add(
      PointGeo(
        q.x + dx * math.cos(-angle) - dy * math.sin(-angle),
        q.y + dx * math.sin(-angle) + dy * math.cos(-angle),
      ),
    );
  }
  return PolygoneGeo(sommets);
}

PointGeo? _centre(FormeGeo f) => switch (f) {
  final CercleGeo c => c.centre,
  final ConiqueGeo k when k.genre != GenreConique.parabole => k.centre,
  _ => null,
};

/// Image par une similitude ; [directe] est faux si elle retourne le plan.
FormeGeo? _image(
  FormeGeo f,
  PointGeo Function(PointGeo) t, {
  bool directe = true,
}) {
  switch (f) {
    case final PointGeo p:
      return t(p);
    case final DroiteGeo d:
      final (debut, fin) = (d.debut, d.fin);
      if (debut != null && fin != null) {
        return DroiteGeo.par(
          t(debut),
          t(fin),
          segment: !d.vecteur,
          vecteur: d.vecteur,
        );
      }
      final origine = debut ?? PointGeo(d.a * d.c, d.b * d.c);
      final loin = PointGeo(origine.x + d.b, origine.y - d.a);
      return DroiteGeo.par(t(origine), t(loin), demiDroite: debut != null);
    case final CercleGeo c:
      final centre = t(c.centre);
      final bord = c.point(0);
      final rayon = centre.distance(t(bord));
      final (depart, balayage) = (c.depart, c.balayage);
      if (depart == null || balayage == null) return CercleGeo(centre, rayon);
      final debut = _angleDe(centre, t(c.point(depart)));
      final fin = _angleDe(centre, t(c.point(depart + balayage)));
      return CercleGeo(
        centre,
        rayon,
        depart: directe ? debut : fin,
        balayage: balayage,
      );
    case final PolygoneGeo g:
      return PolygoneGeo(g.sommets.map(t).toList());
    case final ConiqueGeo k:
      return ConiqueGeo.parCinqPoints(k._cinqPoints().map(t).toList());
    case final LieuGeo l:
      return LieuGeo([
        for (final morceau in l.morceaux) morceau.map(t).toList(),
      ]);
    case NombreGeo():
      return null;
  }
}

FormeGeo? _translation(FormeGeo f, DroiteGeo v) {
  final (debut, fin) = (v.debut, v.fin);
  if (debut == null || fin == null) return null;
  final (dx, dy) = (fin.x - debut.x, fin.y - debut.y);
  return _image(f, (q) => PointGeo(q.x + dx, q.y + dy));
}

FormeGeo? _rotation(FormeGeo f, PointGeo o, double degres) {
  final angle = degres * math.pi / 180;
  final (cos, sin) = (math.cos(angle), math.sin(angle));
  return _image(f, (q) {
    final (x, y) = (q.x - o.x, q.y - o.y);
    return PointGeo(o.x + x * cos - y * sin, o.y + x * sin + y * cos);
  });
}

FormeGeo? _homothetie(FormeGeo f, PointGeo o, double k) {
  if (k.abs() < _epsilon) return null;
  return _image(
    f,
    (q) => PointGeo(o.x + k * (q.x - o.x), o.y + k * (q.y - o.y)),
  );
}

NombreGeo? _longueur(FormeGeo f) => switch (f) {
  final DroiteGeo d when d.estSegment => NombreGeo(d.debut!.distance(d.fin!)),
  final CercleGeo c => NombreGeo(c.rayon * (c.balayage ?? 2 * math.pi)),
  final PolygoneGeo g => NombreGeo(g.perimetre),
  _ => null,
};

AngleGeo? _angle(PointGeo a, PointGeo s, PointGeo b) {
  if (s.distance(a) < _epsilon || s.distance(b) < _epsilon) return null;
  final (depart, fin) = (_angleDe(s, a), _angleDe(s, b));
  final ouverture = (fin - depart) % (2 * math.pi);
  final petit = ouverture <= math.pi;
  final balayage = petit ? ouverture : 2 * math.pi - ouverture;
  return AngleGeo(balayage * 180 / math.pi, s, petit ? depart : fin, balayage);
}

NombreGeo? _aire(FormeGeo f) => switch (f) {
  final PolygoneGeo g => NombreGeo(g.aire),
  final CercleGeo c when !c.estArc => NombreGeo(math.pi * c.rayon * c.rayon),
  final ConiqueGeo k when k.genre == GenreConique.ellipse => NombreGeo(
    math.pi * k.demiA * k.demiB,
  ),
  _ => null,
};

PointGeo? _intersection(FormeGeo a, FormeGeo b, int indice) {
  final points = intersections(a, b);
  return indice < points.length ? points[indice] : null;
}

/// Les points communs à [a] et [b], dans un ordre stable tant que la figure se
/// déforme doucement.
List<PointGeo> intersections(FormeGeo a, FormeGeo b) {
  if (a is PolygoneGeo) {
    return [for (final d in a.cotes) ...intersections(d, b)];
  }
  if (b is PolygoneGeo) {
    return [for (final d in b.cotes) ...intersections(a, d)];
  }
  final points = switch ((a, b)) {
    (final DroiteGeo d, final DroiteGeo e) => _droiteDroite(d, e),
    (final DroiteGeo d, final CercleGeo c) => _droiteCercle(d, c),
    (final CercleGeo c, final DroiteGeo d) => _droiteCercle(d, c),
    (final CercleGeo c, final CercleGeo e) => _cercleCercle(c, e),
    (final DroiteGeo d, final ConiqueGeo k) => k._avecDroite(d),
    (final ConiqueGeo k, final DroiteGeo d) => k._avecDroite(d),
    (final ConiqueGeo k, final ConiqueGeo l) => k._avecConique(l),
    (final ConiqueGeo k, final CercleGeo c) => k._avecConique(
      ConiqueGeo._duCercle(c),
    ),
    (final CercleGeo c, final ConiqueGeo k) => k._avecConique(
      ConiqueGeo._duCercle(c),
    ),
    _ => const <PointGeo>[],
  };
  return points.where((p) => _porte(a, p) && _porte(b, p)).toList();
}

bool _porte(FormeGeo f, PointGeo p) => switch (f) {
  final DroiteGeo d => d.contient(p),
  final CercleGeo c => c.contient(p),
  _ => true,
};

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

/// Comment un objet se montre.
class Apparence {
  /// Crée une apparence.
  new({
    this.nom,
    this.couleur,
    this.visible = true,
    this.nomVisible = true,
    this.pointille = false,
  });

  /// Relit une sauvegarde.
  factory depuisJson(Map<String, dynamic> json) => Apparence(
    nom: json['n'] as String?,
    couleur: json['c'] as int?,
    visible: json['v'] as bool? ?? true,
    nomVisible: json['nv'] as bool? ?? true,
    pointille: json['pt'] as bool? ?? false,
  );

  /// Son nom ; `null` s'il se déduit de ses parents, comme `[AB]`.
  String? nom;

  /// Rang dans la palette, `null` pour la couleur de son genre.
  int? couleur;

  /// Est-il dessiné ?
  bool visible;

  /// Son nom est-il dessiné ?
  bool nomVisible;

  /// Est-il en pointillé ?
  bool pointille;

  /// Pour la sauvegarde.
  Map<String, dynamic> versJson() => {
    'n': ?nom,
    'c': ?couleur,
    if (!visible) 'v': false,
    if (!nomVisible) 'nv': false,
    if (pointille) 'pt': true,
  };
}

/// Une figure dynamique : déplacer un point libre recalcule tout ce qui en
/// dépend. Un objet ne dépend que d'objets créés avant lui.
class Figure {
  final _definitions = <int, Definition>{};
  final _apparences = <int, Apparence>{};
  var _prochain = 0;

  /// Les objets, dans l'ordre de construction.
  Iterable<int> get objets => _definitions.keys;

  /// La définition de [id].
  Definition definition(int id) => _definitions[id]!;

  /// L'apparence de [id].
  Apparence apparence(int id) => _apparences[id]!;

  /// Ajoute un objet et rend son identifiant.
  int ajouter(Definition definition, {Apparence? apparence}) {
    for (final parent in definition.parents) {
      if (!_definitions.containsKey(parent)) {
        throw ArgumentError('parent inconnu : $parent');
      }
    }
    final id = _prochain++;
    _definitions[id] = definition;
    _apparences[id] = apparence ?? Apparence();
    _apparences[id]!.nom ??= _nomAutomatique(id);
    return id;
  }

  /// Le genre de [id].
  CategorieGeo categorie(int id) => switch (_definitions[id]!) {
    PointLibre() || PointSur() => CategorieGeo.point,
    NombreLibre() => CategorieGeo.nombre,
    Lieu() => CategorieGeo.lieu,
    final Construite c => c.genre.categorie ?? categorie(c.parents.first),
  };

  /// Le nom de [id] : le sien, ou celui qui se déduit de ses parents.
  String nom(int id) {
    final nom = _apparences[id]!.nom;
    if (nom != null) return nom;
    final d = _definitions[id]! as Construite;
    final (a, b) = (this.nom(d.parents[0]), this.nom(d.parents[1]));
    return switch (d.genre) {
      GenreConstruction.segment => '[$a$b]',
      GenreConstruction.droite => '($a$b)',
      GenreConstruction.demiDroite => '[$a$b)',
      _ => '$a$b',
    };
  }

  String? _nomAutomatique(int id) {
    final d = _definitions[id]!;
    if (d is Construite &&
        const {
          GenreConstruction.segment,
          GenreConstruction.droite,
          GenreConstruction.demiDroite,
          GenreConstruction.vecteur,
        }.contains(d.genre)) {
      return null;
    }
    // L'image de A s'appelle A′.
    if (d is Construite && d.genre.categorie == null) {
      final image = '${nom(d.parents.first)}′';
      if (!_nomPris(image)) return image;
    }
    final lettres = switch (categorie(id)) {
      CategorieGeo.point => 'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
      CategorieGeo.ligne => 'defgh',
      CategorieGeo.cercle => 'c',
      CategorieGeo.polygone => 'p',
      CategorieGeo.conique => 'k',
      CategorieGeo.nombre => 'abmnrstuvw',
      CategorieGeo.lieu => 'l',
    };
    for (var tour = 0; ; tour++) {
      for (final s in lettres.split('')) {
        final candidat = '$s${tour == 0 ? '' : tour}';
        if (!_nomPris(candidat)) return candidat;
      }
    }
  }

  bool _nomPris(String nom) =>
      _definitions.keys.any((id) => _apparences[id]?.nom == nom);

  /// Renomme [id] ; `false` si le nom est vide ou déjà pris.
  bool renommer(int id, String nom) {
    final propre = nom.trim();
    if (propre.isEmpty) return false;
    if (_apparences[id]!.nom == propre) return true;
    if (_nomPris(propre)) return false;
    _apparences[id]!.nom = propre;
    return true;
  }

  /// Toutes les formes ; `null` pour un objet qui n'existe pas dans cette
  /// position.
  Map<int, FormeGeo?> calculer() {
    final valeurs = <int, FormeGeo?>{};
    _definitions.forEach((id, definition) {
      valeurs[id] = definition is Lieu
          ? _lieu(definition, valeurs)
          : definition.calculer((parent) => valeurs[parent]);
    });
    return valeurs;
  }

  LieuGeo? _lieu(Lieu lieu, Map<int, FormeGeo?> valeurs) {
    final moteur = _definitions[lieu.moteur];
    if (moteur is! PointSur) return null;
    final support = valeurs[moteur.support];
    if (support == null) return null;
    // Ce qui dépend du moteur, jusqu'à la trace : le reste ne bouge pas.
    final touches = {lieu.moteur};
    final chaine = <int>[];
    for (final MapEntry(:key, :value) in _definitions.entries) {
      if (key > lieu.trace) break;
      if (key != lieu.moteur && value.parents.any(touches.contains)) {
        touches.add(key);
        chaine.add(key);
      }
    }
    if (!touches.contains(lieu.trace)) return null;
    final (debut, fin) = _plage(support, moteur.u);
    const pas = 360;
    final locales = <int, FormeGeo?>{};
    FormeGeo? lire(int id) => touches.contains(id) ? locales[id] : valeurs[id];
    final points = <PointGeo?>[];
    for (var i = 0; i <= pas; i++) {
      locales[lieu.moteur] = pointSurForme(
        support,
        debut + (fin - debut) * i / pas,
      );
      for (final id in chaine) {
        locales[id] = _definitions[id]!.calculer(lire);
      }
      points.add(lire(lieu.trace) as PointGeo?);
    }
    return LieuGeo(_morceaux(points));
  }

  (double, double) _plage(FormeGeo support, double u) => switch (support) {
    final DroiteGeo d when d.estSegment => (0, 1),
    final DroiteGeo d when d.estDemiDroite => (0, 40),
    DroiteGeo() => (u - 40, u + 40),
    final CercleGeo c when c.estArc => (0, 1),
    CercleGeo() => (-math.pi, math.pi),
    final PolygoneGeo g => (0, g.sommets.length.toDouble()),
    final ConiqueGeo k => k.plage,
    _ => (0, 0),
  };

  /// Coupe là où le lieu n'existe pas, et là où il saute : une branche
  /// d'hyperbole ne se raccorde pas à l'autre.
  List<List<PointGeo>> _morceaux(List<PointGeo?> points) {
    final ecarts = <double>[];
    for (var i = 1; i < points.length; i++) {
      final (p, q) = (points[i - 1], points[i]);
      if (p != null && q != null) ecarts.add(p.distance(q));
    }
    if (ecarts.isEmpty) return const [];
    ecarts.sort();
    final saut = math.max(ecarts[ecarts.length ~/ 2] * 20, 1e-6);
    final morceaux = <List<PointGeo>>[];
    var courant = <PointGeo>[];
    for (final p in points) {
      if (p == null ||
          (courant.isNotEmpty && p.distance(courant.last) > saut)) {
        if (courant.length > 1) morceaux.add(courant);
        courant = [];
      }
      if (p != null) courant.add(p);
    }
    if (courant.length > 1) morceaux.add(courant);
    return morceaux;
  }

  /// Déplace le point [id], libre ou sur un objet qu'il ne quitte pas.
  void deplacer(int id, double x, double y) {
    switch (_definitions[id]) {
      case final PointLibre point:
        point
          ..x = x
          ..y = y;
      case final PointSur point:
        final support = calculer()[point.support];
        if (support != null) point.u = parametreSurForme(support, x, y);
      case _:
        throw ArgumentError('$id n’est pas libre');
    }
  }

  /// Les points libres dont dépend [id].
  Set<int> pointsLibresDe(int id) {
    final d = _definitions[id]!;
    if (d is PointLibre) return {id};
    return {for (final parent in d.parents) ...pointsLibresDe(parent)};
  }

  /// [id] et ce qu'il entraîne peuvent-ils glisser d'un bloc ? Seulement si
  /// rien d'autre que ses points libres ne le tient, comme un point sur objet.
  bool estTranslatable(int id) {
    final d = _definitions[id]!;
    return switch (d) {
      PointLibre() => true,
      PointSur() || NombreLibre() || Lieu() => false,
      Construite() => d.parents.isNotEmpty && d.parents.every(estTranslatable),
    };
  }

  /// Fait glisser [id] d'un bloc, en déplaçant ses points libres.
  void translater(int id, double dx, double dy) {
    for (final libre in pointsLibresDe(id)) {
      (_definitions[libre]! as PointLibre)
        ..x += dx
        ..y += dy;
    }
  }

  /// Donne au curseur [id] la valeur [valeur].
  void fixerNombre(int id, double valeur) {
    final n = _definitions[id];
    if (n is! NombreLibre) throw ArgumentError('$id n’est pas un curseur');
    n.valeur = valeur;
  }

  /// Retire [id] et tout ce qui en dépend.
  void retirer(int id) {
    final partis = {id};
    for (final MapEntry(:key, :value) in _definitions.entries) {
      if (value.parents.any(partis.contains)) partis.add(key);
    }
    partis
      ..forEach(_definitions.remove)
      ..forEach(_apparences.remove);
  }

  /// Pour la sauvegarde.
  List<Map<String, dynamic>> versJson() => [
    for (final MapEntry(:key, :value) in _definitions.entries)
      {'id': key, ...value.versJson(), 'a': _apparences[key]!.versJson()},
  ];

  /// Relit une sauvegarde.
  static Figure depuisJson(List<dynamic> json) {
    final figure = Figure();
    for (final objet in json.cast<Map<String, dynamic>>()) {
      final id = objet['id'] as int;
      figure._definitions[id] = _lireDefinition(objet);
      figure._prochain = math.max(figure._prochain, id + 1);
      final apparence = objet['a'] as Map<String, dynamic>?;
      figure._apparences[id] = apparence == null
          ? Apparence()
          : Apparence.depuisJson(apparence);
      // Une figure d'avant les noms : ils se donnent dans l'ordre, comme avant.
      figure._apparences[id]!.nom ??= figure._nomAutomatique(id);
    }
    return figure;
  }

  static Definition _lireDefinition(Map<String, dynamic> objet) {
    double reel(String cle) => (objet[cle] as num).toDouble();
    List<int> parents() => (objet['p'] as List<dynamic>).cast<int>();
    return switch (objet['t'] as String) {
      'libre' => PointLibre(reel('x'), reel('y')),
      'sur' => PointSur(parents().single, reel('u')),
      'nombre' => NombreLibre(reel('v'), min: reel('min'), max: reel('max')),
      'lieu' => Lieu(parents()[0], parents()[1]),
      final genre => Construite(
        GenreConstruction.values.byName(genre),
        parents(),
        parametre: objet['k'] as int?,
      ),
    };
  }
}
