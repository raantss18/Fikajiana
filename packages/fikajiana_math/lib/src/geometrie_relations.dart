part of 'geometrie.dart';

/// Ce qu'on peut constater entre deux objets.
enum RelationGeo {
  /// Le même objet, ou deux points au même endroit.
  confondus,

  /// Deux droites parallèles et distinctes.
  paralleles,

  /// Deux droites perpendiculaires.
  perpendiculaires,

  /// Deux segments de même longueur, deux cercles de même rayon, deux nombres
  /// égaux.
  memeLongueur,

  /// Un point sur une ligne, un cercle, un polygone ou une conique.
  appartient,

  /// Une droite et un cercle, ou deux cercles, qui se touchent en un point.
  tangents,

  /// Deux cercles de même centre.
  concentriques,
}

const double _toleranceRelation = 1e-7;

/// Ce qui est vrai de [a] et [b] dans cette position.
Set<RelationGeo> relationsEntre(FormeGeo a, FormeGeo b) {
  bool egal(double u, double v) => (u - v).abs() < _toleranceRelation;
  final relations = <RelationGeo>{};
  switch ((a, b)) {
    case (final PointGeo p, final PointGeo q):
      if (p.distance(q) < _toleranceRelation) {
        relations.add(RelationGeo.confondus);
      }
    case (final PointGeo p, final FormeGeo f) ||
        (final FormeGeo f, final PointGeo p):
      if (f is! NombreGeo && f is! LieuGeo && _surForme(f, p)) {
        relations.add(RelationGeo.appartient);
      }
    case (final DroiteGeo d, final DroiteGeo e):
      final det = d.a * e.b - d.b * e.a;
      if (det.abs() < _toleranceRelation) {
        // (a, b) et (-a, -b) décrivent la même direction.
        final signe = d.a * e.a + d.b * e.b > 0 ? 1 : -1;
        relations.add(
          egal(d.c, signe * e.c)
              ? RelationGeo.confondus
              : RelationGeo.paralleles,
        );
      }
      if (egal(d.a * e.a + d.b * e.b, 0)) {
        relations.add(RelationGeo.perpendiculaires);
      }
      if (d.estSegment &&
          e.estSegment &&
          egal(d.debut!.distance(d.fin!), e.debut!.distance(e.fin!))) {
        relations.add(RelationGeo.memeLongueur);
      }
    case (final DroiteGeo d, final CercleGeo c) ||
        (final CercleGeo c, final DroiteGeo d):
      final ecart = (d.a * c.centre.x + d.b * c.centre.y - d.c).abs();
      if (egal(ecart, c.rayon)) relations.add(RelationGeo.tangents);
    case (final CercleGeo c, final CercleGeo e):
      final ecart = c.centre.distance(e.centre);
      if (egal(c.rayon, e.rayon)) relations.add(RelationGeo.memeLongueur);
      if (egal(ecart, 0)) {
        relations.add(
          egal(c.rayon, e.rayon)
              ? RelationGeo.confondus
              : RelationGeo.concentriques,
        );
      } else if (egal(ecart, c.rayon + e.rayon) ||
          egal(ecart, (c.rayon - e.rayon).abs())) {
        relations.add(RelationGeo.tangents);
      }
    case (final NombreGeo n, final NombreGeo m):
      if (egal(n.valeur, m.valeur)) relations.add(RelationGeo.memeLongueur);
    case _:
      break;
  }
  return relations;
}

bool _surForme(FormeGeo f, PointGeo p) => switch (f) {
  final ConiqueGeo k => k.evaluer(p.x, p.y).abs() < _toleranceRelation,
  _ => distanceA(f, p.x, p.y) < _toleranceRelation,
};

/// Une relation constatée, et si elle tient quand la figure se déforme.
class Constat {
  /// Crée un constat.
  const new(this.relation, {required this.resiste});

  /// Ce qui est vrai dans cette position.
  final RelationGeo relation;

  /// Reste-t-elle vraie dans toutes les positions essayées ?
  final bool resiste;
}

/// Combien de positions de la figure un constat essaie.
const int positionsEssayees = 24;

/// La relation entre deux objets de la figure.
extension Constater on Figure {
  /// Ce qui est vrai de [a] et [b], et si cela résiste à [positionsEssayees]
  /// déformations au hasard : un indice fort, pas une démonstration.
  List<Constat> constater(int a, int b) {
    final depart = calculer();
    final (fa, fb) = (depart[a], depart[b]);
    if (fa == null || fb == null) return const [];
    final ici = relationsEntre(fa, fb);
    if (ici.isEmpty) return const [];
    final tient = {for (final r in ici) r: true};
    final sauvegarde = versJson();
    final hasard = math.Random(42);
    double ecart() => (hasard.nextDouble() - 0.5) * 8;
    for (var essai = 0; essai < positionsEssayees; essai++) {
      for (final id in objets) {
        switch (definition(id)) {
          case final PointLibre p:
            p
              ..x += ecart()
              ..y += ecart();
          case final PointSur p:
            p.u += ecart() / 8;
          case final NombreLibre n:
            n.valeur = n.min + hasard.nextDouble() * (n.max - n.min);
          case Construite() || Lieu():
            break;
        }
      }
      final formes = calculer();
      final (ga, gb) = (formes[a], formes[b]);
      if (ga == null || gb == null) continue;
      final alors = relationsEntre(ga, gb);
      for (final r in ici) {
        if (!alors.contains(r)) tient[r] = false;
      }
    }
    _restaurer(sauvegarde);
    return [for (final r in ici) Constat(r, resiste: tient[r]!)];
  }

  void _restaurer(List<Map<String, dynamic>> sauvegarde) {
    for (final objet in sauvegarde) {
      final id = objet['id'] as int;
      switch (definition(id)) {
        case final PointLibre p:
          p
            ..x = (objet['x'] as num).toDouble()
            ..y = (objet['y'] as num).toDouble();
        case final PointSur p:
          p.u = (objet['u'] as num).toDouble();
        case final NombreLibre n:
          n.valeur = (objet['v'] as num).toDouble();
        case Construite() || Lieu():
          break;
      }
    }
  }
}
