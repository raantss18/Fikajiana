import 'dart:math' as math;
import 'dart:ui';

/// Forme nette obtenue en maintenant le stylet à la fin d'un trait.
sealed class Forme {
  const new();

  /// Points de la forme, à l'espacement voulu pour le rendu et la gomme.
  List<Offset> echantillons();
}

class FormeLigne extends Forme {
  const new(this.a, this.b);

  final Offset a;
  final Offset b;

  @override
  List<Offset> echantillons() => _segment(a, b);
}

class FormeCercle extends Forme {
  const new(this.centre, this.rayon);

  final Offset centre;
  final double rayon;

  @override
  List<Offset> echantillons() {
    final n = math.max(24, (2 * math.pi * rayon / 6).ceil());
    return [
      for (var i = 0; i <= n; i++)
        centre + Offset.fromDirection(2 * math.pi * i / n, rayon),
    ];
  }
}

/// Triangle ou quadrilatère fermé, sommets dans l'ordre du tracé.
class FormePolygone extends Forme {
  const new(this.sommets);

  final List<Offset> sommets;

  @override
  List<Offset> echantillons() => [
    for (var i = 0; i < sommets.length; i++)
      ..._segment(sommets[i], sommets[(i + 1) % sommets.length]),
  ];
}

List<Offset> _segment(Offset a, Offset b) {
  final n = math.max(1, ((b - a).distance / 6).ceil());
  return [for (var i = 0; i <= n; i++) Offset.lerp(a, b, i / n)!];
}

List<double> _vers(Offset p) => [p.dx, p.dy];
Offset _depuis(dynamic p) {
  final l = (p as List<dynamic>).cast<num>();
  return Offset(l[0].toDouble(), l[1].toDouble());
}

Map<String, dynamic> formeVersJson(Forme forme) => switch (forme) {
  FormeLigne(:final a, :final b) => {
    'type': 'ligne',
    'a': _vers(a),
    'b': _vers(b),
  },
  FormeCercle(:final centre, :final rayon) => {
    'type': 'cercle',
    'centre': _vers(centre),
    'rayon': rayon,
  },
  FormePolygone(:final sommets) => {
    'type': 'polygone',
    'sommets': sommets.map(_vers).toList(),
  },
};

Forme formeDepuisJson(Map<String, dynamic> json) => switch (json['type']) {
  'ligne' => FormeLigne(_depuis(json['a']), _depuis(json['b'])),
  'cercle' => FormeCercle(
    _depuis(json['centre']),
    (json['rayon'] as num).toDouble(),
  ),
  'polygone' => FormePolygone(
    (json['sommets'] as List<dynamic>).map(_depuis).toList(),
  ),
  _ => throw FormatException('forme inconnue : ${json['type']}'),
};

const double _longueurMinimale = 24;
const double _ecartLigne = 0.05;
const double _ouvertureFermee = 0.2;
const double _ecartCercle = 0.07;
const double _toleranceSommets = 0.09;
const double _angleAxe = 5 * math.pi / 180;
const double _angleDroit = 20 * math.pi / 180;

/// Reconnaît une ligne, un cercle, un triangle ou un rectangle, sinon `null`.
///
/// Géométrie seule, sans apprentissage : droite par l'écart à la corde, cercle
/// par moindres carrés, polygone par Ramer-Douglas-Peucker. Les seuils sont des
/// choix de départ, à ajuster sur de vrais traits.
Forme? reconnaitreForme(List<Offset> points) {
  if (points.length < 5) return null;
  final longueur = _longueur(points);
  if (longueur < _longueurMinimale) return null;

  final debut = points.first;
  final fin = points.last;
  final fermee = (fin - debut).distance < _ouvertureFermee * longueur;
  if (!fermee) {
    return _ecartMaximal(points, debut, fin) <
            _ecartLigne * (fin - debut).distance
        ? FormeLigne(debut, _redresser(debut, fin))
        : null;
  }

  final cercle = _ajusterCercle(points);
  if (cercle != null) return cercle;

  final sommets = _sommetsFermes(points, longueur);
  if (sommets.length == 3) return FormePolygone(sommets);
  if (sommets.length == 4) return _rectangle(sommets);
  return null;
}

double _longueur(List<Offset> points) {
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += (points[i] - points[i - 1]).distance;
  }
  return total;
}

double _distanceAuSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final carre = ab.distanceSquared;
  if (carre == 0) return (p - a).distance;
  final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / carre).clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

double _ecartMaximal(List<Offset> points, Offset a, Offset b) {
  var maximum = 0.0;
  for (final p in points) {
    maximum = math.max(maximum, _distanceAuSegment(p, a, b));
  }
  return maximum;
}

/// Aligne la ligne sur l'horizontale ou la verticale si elle en est tout près.
Offset _redresser(Offset a, Offset b) {
  final angle = (b - a).direction;
  final horizontal = math.min(angle.abs(), math.pi - angle.abs());
  final vertical = (angle.abs() - math.pi / 2).abs();
  if (horizontal < _angleAxe) return Offset(b.dx, a.dy);
  if (vertical < _angleAxe) return Offset(a.dx, b.dy);
  return b;
}

/// Cercle de Kåsa : moindres carrés linéaires sur `x² + y² + Dx + Ey + F = 0`.
FormeCercle? _ajusterCercle(List<Offset> points) {
  var (sx, sy, sxx, syy, sxy, sz, sxz, syz) = (
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
  );
  for (final p in points) {
    final z = p.dx * p.dx + p.dy * p.dy;
    sx += p.dx;
    sy += p.dy;
    sxx += p.dx * p.dx;
    syy += p.dy * p.dy;
    sxy += p.dx * p.dy;
    sz += z;
    sxz += p.dx * z;
    syz += p.dy * z;
  }
  final n = points.length.toDouble();
  final a = [
    [sxx, sxy, sx],
    [sxy, syy, sy],
    [sx, sy, n],
  ];
  final solution = _resoudre3(a, [-sxz, -syz, -sz]);
  if (solution == null) return null;
  final centre = Offset(-solution[0] / 2, -solution[1] / 2);
  final carre = centre.distanceSquared - solution[2];
  if (carre <= 0) return null;
  final rayon = math.sqrt(carre);
  var somme = 0.0;
  for (final p in points) {
    final e = (p - centre).distance - rayon;
    somme += e * e;
  }
  return math.sqrt(somme / n) / rayon < _ecartCercle
      ? FormeCercle(centre, rayon)
      : null;
}

List<double>? _resoudre3(List<List<double>> a, List<double> b) {
  double det(List<List<double>> m) =>
      m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) -
      m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0]) +
      m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]);
  final d = det(a);
  if (d.abs() < 1e-9) return null;
  return [
    for (var c = 0; c < 3; c++)
      det([
            for (var l = 0; l < 3; l++)
              [...a[l].sublist(0, c), b[l], ...a[l].sublist(c + 1)],
          ]) /
          d,
  ];
}

/// Sommets d'un tracé fermé. Ramer-Douglas-Peucker veut deux extrémités : on
/// coupe au point le plus loin du départ, puis on fusionne début et fin.
List<Offset> _sommetsFermes(List<Offset> points, double longueur) {
  final tolerance = _toleranceSommets * longueur / 4;
  var loin = 0;
  var maximum = -1.0;
  for (var i = 0; i < points.length; i++) {
    final d = (points[i] - points.first).distance;
    if (d > maximum) (loin, maximum) = (i, d);
  }
  final premier = _rdp(points.sublist(0, loin + 1), tolerance);
  final second = _rdp(points.sublist(loin), tolerance);
  final sommets = [...premier, ...second.skip(1)]..removeLast();

  // Le départ n'est pas forcément un coin : retiré s'il est sur une arête.
  if (sommets.length > 3) {
    final avant = sommets.last;
    final apres = sommets[1];
    if (_distanceAuSegment(sommets.first, avant, apres) < tolerance) {
      sommets.removeAt(0);
    }
  }
  return sommets;
}

/// Ramer (1972), Douglas et Peucker (1973).
List<Offset> _rdp(List<Offset> points, double tolerance) {
  if (points.length < 3) return points;
  final a = points.first;
  final b = points.last;
  var indice = 0;
  var maximum = 0.0;
  for (var i = 1; i < points.length - 1; i++) {
    final d = _distanceAuSegment(points[i], a, b);
    if (d > maximum) (indice, maximum) = (i, d);
  }
  if (maximum <= tolerance) return [a, b];
  return [
    ..._rdp(points.sublist(0, indice + 1), tolerance),
    ..._rdp(points.sublist(indice), tolerance).skip(1),
  ];
}

/// Rectangle aligné sur les axes s'il en est proche, sinon le tracé tel quel.
Forme _rectangle(List<Offset> s) {
  double angleAuSommet(int i) {
    final u = s[(i + 3) % 4] - s[i];
    final v = s[(i + 1) % 4] - s[i];
    final cos = (u.dx * v.dx + u.dy * v.dy) / (u.distance * v.distance);
    return math.acos(cos.clamp(-1.0, 1.0));
  }

  final droit = [
    for (var i = 0; i < 4; i++) (angleAuSommet(i) - math.pi / 2).abs(),
  ].every((e) => e < _angleDroit);
  if (!droit) return FormePolygone(s);

  final direction = (s[1] - s[0]).direction;
  final ecartAxe = [
    direction.abs(),
    (direction.abs() - math.pi / 2).abs(),
    (direction.abs() - math.pi).abs(),
  ].reduce(math.min);
  if (ecartAxe >= _angleDroit) return FormePolygone(s);

  final xs = s.map((p) => p.dx);
  final ys = s.map((p) => p.dy);
  final (g, d) = (xs.reduce(math.min), xs.reduce(math.max));
  final (h, b) = (ys.reduce(math.min), ys.reduce(math.max));
  return FormePolygone([
    Offset(g, h),
    Offset(d, h),
    Offset(d, b),
    Offset(g, b),
  ]);
}
