import 'dart:math' as math;
import 'dart:ui';

/// Ce trait est-il une rature, ce gribouillage qu'on fait pour effacer ?
///
/// Un aller-retour répété, ou un tournoiement : beaucoup de chemin pour peu de
/// place. Un `m`, un `w` ou un `8` font moins de retours. Seul, ce test ne
/// décide pas : encore faut-il qu'il y ait quelque chose dessous.
bool estRature(List<Offset> points) {
  final (:demiTours, :rapport) = _mesurer(points);
  // Relevé au vrai stylet sur le Pad 7 (ADR 0021) : une rature naturelle est
  // un zigzag qui avance, de 6 retours et d'un rapport de 2,5 ; sur toute une
  // expression, 8 retours et 1,9. Le `m` le plus proche fait 5 retours. Un `m`
  // lié écrit sur de l'encre reste possible : Annuler est là.
  if (demiTours >= 8 && rapport >= 1.7) return true;
  if (demiTours >= 6 && rapport >= 2.2) return true;
  if (demiTours >= 4 && rapport >= 3.2) return true;
  return demiTours >= 3 && rapport >= 4;
}

/// Une rature vite faite, dont la forme ressemble à un `w`. Elle ne compte que
/// si elle couvre presque tout un trait : voir [couvreBien].
bool estRatureHesitante(List<Offset> points) {
  final (:demiTours, :rapport) = _mesurer(points);
  return demiTours >= 4 && rapport >= 2;
}

({int demiTours, double rapport}) _mesurer(List<Offset> points) {
  const rien = (demiTours: 0, rapport: 0.0);
  if (points.length < 12) return rien;
  final cadre = _cadre(points);
  final diagonale = cadre.size.longestSide;
  if (diagonale < 12) return rien;
  final pas = math.max(4, diagonale / 24).toDouble();
  final jalons = _jalonner(points, pas);
  if (jalons.length < 8) return rien;

  var longueur = 0.0;
  for (var i = 1; i < jalons.length; i++) {
    longueur += (jalons[i] - jalons[i - 1]).distance;
  }
  final etendue = math.sqrt(
    cadre.width * cadre.width + cadre.height * cadre.height,
  );
  // Les retours en arrière, sur l'axe où il y en a le plus.
  return (
    demiTours: math.max(
      _retours([for (final p in jalons) p.dx]),
      _retours([for (final p in jalons) p.dy]),
    ),
    rapport: longueur / etendue,
  );
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

/// La part des points de [trait] sous la [rature], de 0 à 1.
double couverture(List<Offset> trait, Rect rature) {
  if (trait.isEmpty) return 0;
  final zone = rature.inflate(6);
  return trait.where(zone.contains).length / trait.length;
}

/// Un trait est emporté dès qu'un bon tiers est couvert : une rature est
/// souvent moins haute que ce qu'elle barre (43 % relevés au stylet).
bool estSousRature(List<Offset> trait, Rect rature) =>
    couverture(trait, rature) >= 0.35;

/// La rature couvre-t-elle presque tout [trait] ? On n'écrit pas par-dessus ce
/// qu'on vient d'écrire : c'est ce qui distingue une rature hésitante d'un `w`.
bool couvreBien(List<Offset> trait, Rect rature) =>
    couverture(trait, rature) >= 0.7;

/// Le rectangle couvert par une rature.
Rect cadreDeRature(List<Offset> points) => _cadre(points);
