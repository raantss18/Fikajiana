import 'dart:ui';

/// Un point d'un trait, en pixels logiques, avec la pression du stylet.
class PointEncre {
  const new(this.x, this.y, this.pression);

  factory depuisJson(List<dynamic> json) => PointEncre(
    (json[0] as num).toDouble(),
    (json[1] as num).toDouble(),
    (json[2] as num).toDouble(),
  );

  final double x;
  final double y;
  final double pression;

  Offset get position => Offset(x, y);

  List<double> versJson() => [x, y, pression];
}

/// Un trait : ses points et le rang du stylo qui l'a écrit.
class Trait {
  const new(this.points, {this.stylo = 0});

  final List<PointEncre> points;
  final int stylo;
}

/// Traits écrits sur une feuille, avec annuler et refaire.
class Encre {
  final List<Trait> _traits = [];
  final List<List<Trait>> _annulations = [];
  final List<List<Trait>> _retablissements = [];

  List<Trait> get traits => List.unmodifiable(_traits);
  bool get estVide => _traits.isEmpty;
  bool get peutAnnuler => _annulations.isNotEmpty;
  bool get peutRefaire => _retablissements.isNotEmpty;

  void _memoriser() {
    _annulations.add([..._traits]);
    _retablissements.clear();
  }

  void commencer(PointEncre point, {int stylo = 0}) {
    _memoriser();
    _traits.add(Trait([point], stylo: stylo));
  }

  void prolonger(PointEncre point) {
    if (_traits.isEmpty) return;
    final dernier = _traits.last;
    _traits.last = Trait([...dernier.points, point], stylo: dernier.stylo);
  }

  /// Retire les traits qui passent à moins de [rayon] de [position].
  void gommer(Offset position, double rayon) {
    bool touche(Trait trait) =>
        trait.points.any((p) => (p.position - position).distance <= rayon);
    if (!_traits.any(touche)) return;
    _memoriser();
    _traits.removeWhere(touche);
  }

  void effacer() {
    if (_traits.isEmpty) return;
    _memoriser();
    _traits.clear();
  }

  void annuler() {
    if (_annulations.isEmpty) return;
    _retablissements.add([..._traits]);
    _traits
      ..clear()
      ..addAll(_annulations.removeLast());
  }

  void refaire() {
    if (_retablissements.isEmpty) return;
    _annulations.add([..._traits]);
    _traits
      ..clear()
      ..addAll(_retablissements.removeLast());
  }

  /// Rectangle qui contient tous les points, ou `null` sans encre.
  Rect? get cadre {
    final points = _traits.expand((trait) => trait.points);
    if (points.isEmpty) return null;
    var (gauche, haut) = (double.infinity, double.infinity);
    var (droite, bas) = (double.negativeInfinity, double.negativeInfinity);
    for (final p in points) {
      if (p.x < gauche) gauche = p.x;
      if (p.x > droite) droite = p.x;
      if (p.y < haut) haut = p.y;
      if (p.y > bas) bas = p.y;
    }
    return Rect.fromLTRB(gauche, haut, droite, bas);
  }

  List<List<List<double>>> versJson() => [
    for (final trait in _traits) [for (final p in trait.points) p.versJson()],
  ];
}

/// Chemin lissé d'un trait : courbes passant par les milieux des points.
Path cheminDuTrait(List<PointEncre> trait) {
  final chemin = Path()..moveTo(trait.first.x, trait.first.y);
  if (trait.length == 1) {
    return chemin..lineTo(trait.first.x + 0.01, trait.first.y);
  }
  for (var i = 1; i < trait.length - 1; i++) {
    final (a, b) = (trait[i], trait[i + 1]);
    chemin.quadraticBezierTo(a.x, a.y, (a.x + b.x) / 2, (a.y + b.y) / 2);
  }
  return chemin..lineTo(trait.last.x, trait.last.y);
}
