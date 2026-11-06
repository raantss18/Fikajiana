import 'dart:math' as math;
import 'dart:ui';

/// Ce trait est-il une rature, ce gribouillage qu'on fait pour effacer ?
///
/// Un aller-retour répété, ou un tournoiement : beaucoup de chemin pour peu de
/// place. Un `m`, un `w` ou un `8` font moins de retours. Seul, ce test ne
/// décide pas : encore faut-il qu'il y ait quelque chose dessous.
bool estRature(List<Offset> points) {
  if (points.length < 12) return false;
  final cadre = _cadre(points);
  final diagonale = cadre.size.longestSide;
  if (diagonale < 12) return false;
  final pas = math.max(4, diagonale / 24).toDouble();
  final jalons = _jalonner(points, pas);
  if (jalons.length < 8) return false;

  var longueur = 0.0;
  for (var i = 1; i < jalons.length; i++) {
    longueur += (jalons[i] - jalons[i - 1]).distance;
  }
  final etendue = math.sqrt(
    cadre.width * cadre.width + cadre.height * cadre.height,
  );
  final rapport = longueur / etendue;

  // Les retours en arrière, sur l'axe où il y en a le plus.
  final demiTours = math.max(
    _retours([for (final p in jalons) p.dx]),
    _retours([for (final p in jalons) p.dy]),
  );
  if (demiTours >= 4 && rapport >= 3.2) return true;
  return demiTours >= 3 && rapport >= 4;
}

/// Combien de fois [valeurs] repart en sens inverse, d'au moins 15 % de son
/// étendue : un petit tremblement ne compte pas.
int _retours(List<double> valeurs) {
  final etendue = valeurs.reduce(math.max) - valeurs.reduce(math.min);
  final seuil = 0.15 * etendue;
  var retours = 0;
  var sens = 0;
  var extreme = valeurs.first;
  for (final v in valeurs.skip(1)) {
    if (sens >= 0 && v > extreme) {
      sens = 1;
      extreme = v;
    } else if (sens <= 0 && v < extreme) {
      sens = -1;
      extreme = v;
    } else if ((v - extreme).abs() >= seuil) {
      retours++;
      sens = -sens;
      extreme = v;
    }
  }
  return retours;
}

Rect _cadre(List<Offset> points) {
  var (g, h, d, b) = (
    points.first.dx,
    points.first.dy,
    points.first.dx,
    points.first.dy,
  );
  for (final p in points) {
    g = math.min(g, p.dx);
    d = math.max(d, p.dx);
    h = math.min(h, p.dy);
    b = math.max(b, p.dy);
  }
  return Rect.fromLTRB(g, h, d, b);
}

/// Des points espacés de [pas] : la vitesse du doigt ne compte plus.
List<Offset> _jalonner(List<Offset> points, double pas) {
  final jalons = [points.first];
  for (final p in points.skip(1)) {
    if ((p - jalons.last).distance >= pas) jalons.add(p);
  }
  return jalons;
}

/// Les points de [trait] sont-ils pour moitié au moins sous la rature ?
bool estSousRature(List<Offset> trait, Rect rature) {
  if (trait.isEmpty) return false;
  final zone = rature.inflate(4);
  return trait.where(zone.contains).length * 2 >= trait.length;
}

/// Le rectangle couvert par une rature.
Rect cadreDeRature(List<Offset> points) => _cadre(points);
