import 'dart:convert';
import 'dart:io';

import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter/foundation.dart';

/// Ce qu'on peut faire sur la figure.
enum OutilGeo {
  deplacer([]),
  point([_Attendu.point]),
  segment([_Attendu.point, _Attendu.point]),
  droite([_Attendu.point, _Attendu.point]),
  cercle([_Attendu.point, _Attendu.point]),
  milieu([_Attendu.point, _Attendu.point]),
  mediatrice([_Attendu.point, _Attendu.point]),
  bissectrice([_Attendu.point, _Attendu.point, _Attendu.point]),
  parallele([_Attendu.droite, _Attendu.point]),
  perpendiculaire([_Attendu.droite, _Attendu.point]),
  intersection([_Attendu.courbe, _Attendu.courbe]),
  gomme([_Attendu.objet]);

  new(this._attendus);

  final List<_Attendu> _attendus;
}

enum _Attendu { point, droite, courbe, objet }

/// La distance de ([x], [y]) à une forme, ou l'infini si elle n'existe pas.
double distanceA(FormeGeo? forme, double x, double y) {
  return switch (forme) {
    final PointGeo p => p.distance(PointGeo(x, y)),
    final DroiteGeo d => _distanceDroite(d, x, y),
    final CercleGeo c => (c.centre.distance(PointGeo(x, y)) - c.rayon).abs(),
    null => double.infinity,
  };
}

double _distanceDroite(DroiteGeo d, double x, double y) {
  final ecart = d.a * x + d.b * y - d.c;
  final pied = PointGeo(x - d.a * ecart, y - d.b * ecart);
  if (d.contient(pied)) return ecart.abs();
  return [
    PointGeo(x, y).distance(d.debut!),
    PointGeo(x, y).distance(d.fin!),
  ].reduce((a, b) => a < b ? a : b);
}

/// La figure en cours et l'outil choisi : tout ce que fait un toucher.
class Atelier extends ChangeNotifier {
  new({this.fichier}) {
    final fichier = this.fichier;
    if (fichier == null || !fichier.existsSync()) return;
    try {
      final json = jsonDecode(fichier.readAsStringSync()) as List<dynamic>;
      _figure = Figure.depuisJson(json);
    } on Object {
      // Un fichier abîmé est mis de côté, jamais écrasé.
      fichier.renameSync('${fichier.path}.illisible');
    }
  }

  final File? fichier;
  Figure _figure = Figure();
  OutilGeo _outil = OutilGeo.deplacer;
  final List<int> _choisis = [];
  Map<int, FormeGeo?>? _formes;

  OutilGeo get outil => _outil;
  List<int> get choisis => List.unmodifiable(_choisis);
  Figure get figure => _figure;
  bool get estVide => _figure.objets.isEmpty;

  Map<int, FormeGeo?> get formes => _formes ??= _figure.calculer();

  /// Le rang du point parmi les points : A, B, C…
  String nomDuPoint(int id) {
    var rang = 0;
    for (final autre in _figure.objets) {
      if (autre == id) break;
      if (_estPoint(autre)) rang++;
    }
    final lettre = String.fromCharCode(65 + rang % 26);
    return rang < 26 ? lettre : '$lettre${rang ~/ 26}';
  }

  bool _estPoint(int id) {
    final d = _figure.definition(id);
    return d is PointLibre ||
        (d is Construite &&
            const {
              GenreConstruction.milieu,
              GenreConstruction.intersection1,
              GenreConstruction.intersection2,
            }.contains(d.genre));
  }

  set outil(OutilGeo valeur) {
    _outil = valeur;
    _choisis.clear();
    notifyListeners();
  }

  /// L'objet le plus proche à moins de [tolerance], les points d'abord : un
  /// point posé sur une droite doit rester attrapable.
  int? objetProche(
    double x,
    double y,
    double tolerance, {
    bool Function(FormeGeo)? filtre,
  }) {
    int? meilleur;
    int? meilleurPoint;
    var (distance, distancePoint) = (tolerance, tolerance);
    formes.forEach((id, forme) {
      if (forme == null || (filtre != null && !filtre(forme))) return;
      final d = distanceA(forme, x, y);
      if (forme is PointGeo && d < distancePoint) {
        meilleurPoint = id;
        distancePoint = d;
      }
      if (d < distance) {
        meilleur = id;
        distance = d;
      }
    });
    return meilleurPoint ?? meilleur;
  }

  /// Le point libre à attraper en ([x], [y]), s'il y en a un.
  int? pointLibreProche(double x, double y, double tolerance) {
    if (_outil != OutilGeo.deplacer) return null;
    int? meilleur;
    var meilleure = tolerance;
    for (final id in _figure.objets) {
      if (_figure.definition(id) is! PointLibre) continue;
      final d = distanceA(formes[id], x, y);
      if (d < meilleure) {
        meilleur = id;
        meilleure = d;
      }
    }
    return meilleur;
  }

  /// Un toucher en ([x], [y]) ; `true` s'il a servi à quelque chose.
  bool toucher(double x, double y, double tolerance) {
    final attendus = _outil._attendus;
    if (attendus.isEmpty) return false;
    final attendu = attendus[_choisis.length];
    final id = _trouver(attendu, x, y, tolerance);
    if (id == null) return false;
    _choisis.add(id);
    if (_choisis.length == attendus.length) {
      _construire();
      _choisis.clear();
    }
    _changer();
    return true;
  }

  int? _trouver(_Attendu attendu, double x, double y, double tolerance) {
    switch (attendu) {
      case _Attendu.point:
        return objetProche(x, y, tolerance, filtre: (f) => f is PointGeo) ??
            _figure.ajouter(PointLibre(x, y));
      case _Attendu.droite:
        return objetProche(x, y, tolerance, filtre: (f) => f is DroiteGeo);
      case _Attendu.courbe:
        return objetProche(x, y, tolerance, filtre: (f) => f is! PointGeo);
      case _Attendu.objet:
        return objetProche(x, y, tolerance);
    }
  }

  void _construire() {
    final c = _choisis;
    void creer(GenreConstruction genre) =>
        _figure.ajouter(Construite(genre, List.of(c)));
    switch (_outil) {
      case OutilGeo.deplacer || OutilGeo.point:
        break;
      case OutilGeo.segment:
        creer(GenreConstruction.segment);
      case OutilGeo.droite:
        creer(GenreConstruction.droite);
      case OutilGeo.cercle:
        creer(GenreConstruction.cercle);
      case OutilGeo.milieu:
        creer(GenreConstruction.milieu);
      case OutilGeo.mediatrice:
        creer(GenreConstruction.mediatrice);
      case OutilGeo.bissectrice:
        creer(GenreConstruction.bissectrice);
      case OutilGeo.parallele:
        creer(GenreConstruction.parallele);
      case OutilGeo.perpendiculaire:
        creer(GenreConstruction.perpendiculaire);
      case OutilGeo.intersection:
        if (c[0] == c[1]) return;
        creer(GenreConstruction.intersection1);
        // Une droite et une droite n'ont qu'un point commun.
        final deuxDroites =
            formes[c[0]] is DroiteGeo && formes[c[1]] is DroiteGeo;
        if (!deuxDroites) creer(GenreConstruction.intersection2);
      case OutilGeo.gomme:
        _figure.retirer(c.single);
    }
  }

  void deplacer(int id, double x, double y) {
    _figure.deplacer(id, x, y);
    _changer();
  }

  /// Retire le dernier objet créé.
  void annuler() {
    if (estVide) return;
    _figure.retirer(_figure.objets.last);
    _choisis.clear();
    _changer();
  }

  void effacer() {
    _figure = Figure();
    _choisis.clear();
    _changer();
  }

  void _changer() {
    _formes = null;
    notifyListeners();
    fichier?.writeAsStringSync(jsonEncode(_figure.versJson()));
  }
}
