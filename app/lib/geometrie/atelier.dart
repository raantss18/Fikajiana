import 'dart:convert';
import 'dart:io';

import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter/foundation.dart';

/// Les familles de la boîte à outils.
enum GroupeOutils {
  base,
  points,
  lignes,
  cercles,
  polygones,
  coniques,
  transformations,
  mesures,
  avance,
}

/// Ce qu'un outil demande en plus des objets touchés.
enum NombreDemande { rayon, angle, rapport, cotes }

enum _Attendu {
  /// Un point, créé au besoin à l'endroit touché.
  point,

  /// Un point qui existe déjà.
  pointExistant,

  /// Un point sur objet, qui peut parcourir son support.
  pointSur,
  droite,
  vecteur,
  courbe,
  cercleOuConique,
  polygone,
  image,
  objet,

  /// Un segment, un cercle, un polygone, ou le premier point d'une distance.
  longueur,

  /// Le second point d'une distance, ou une droite.
  pointOuDroite,
  surface,
}

/// Ce qu'on peut faire sur la figure.
enum OutilGeo {
  deplacer(GroupeOutils.base, []),
  gomme(GroupeOutils.base, [_Attendu.objet]),
  point(GroupeOutils.points, [_Attendu.point]),
  milieu(GroupeOutils.points, [
    _Attendu.point,
    _Attendu.point,
  ], genre: GenreConstruction.milieu),
  intersection(GroupeOutils.points, [_Attendu.courbe, _Attendu.courbe]),
  centre(GroupeOutils.points, [
    _Attendu.cercleOuConique,
  ], genre: GenreConstruction.centre),
  centreGravite(GroupeOutils.points, [
    _Attendu.polygone,
  ], genre: GenreConstruction.centreGravite),
  segment(GroupeOutils.lignes, [
    _Attendu.point,
    _Attendu.point,
  ], genre: GenreConstruction.segment),
  droite(GroupeOutils.lignes, [
    _Attendu.point,
    _Attendu.point,
  ], genre: GenreConstruction.droite),
  demiDroite(GroupeOutils.lignes, [
    _Attendu.point,
    _Attendu.point,
  ], genre: GenreConstruction.demiDroite),
  vecteur(GroupeOutils.lignes, [
    _Attendu.point,
    _Attendu.point,
  ], genre: GenreConstruction.vecteur),
  parallele(
    GroupeOutils.lignes,
    [_Attendu.droite, _Attendu.point],
    genre: GenreConstruction.parallele,
    ordreLibre: true,
  ),
  perpendiculaire(
    GroupeOutils.lignes,
    [_Attendu.droite, _Attendu.point],
    genre: GenreConstruction.perpendiculaire,
    ordreLibre: true,
  ),
  mediatrice(GroupeOutils.lignes, [
    _Attendu.point,
    _Attendu.point,
  ], genre: GenreConstruction.mediatrice),
  bissectrice(GroupeOutils.lignes, [
    _Attendu.point,
    _Attendu.point,
    _Attendu.point,
  ], genre: GenreConstruction.bissectrice),
  tangente(GroupeOutils.lignes, [
    _Attendu.cercleOuConique,
    _Attendu.point,
  ], ordreLibre: true),
  cercle(GroupeOutils.cercles, [
    _Attendu.point,
    _Attendu.point,
  ], genre: GenreConstruction.cercle),
  cercleRayon(
    GroupeOutils.cercles,
    [_Attendu.point],
    genre: GenreConstruction.cercleRayon,
    nombre: NombreDemande.rayon,
  ),
  cercleTroisPoints(GroupeOutils.cercles, [
    _Attendu.point,
    _Attendu.point,
    _Attendu.point,
  ], genre: GenreConstruction.cercleTroisPoints),
  arc(GroupeOutils.cercles, [
    _Attendu.point,
    _Attendu.point,
    _Attendu.point,
  ], genre: GenreConstruction.arc),
  arcTroisPoints(GroupeOutils.cercles, [
    _Attendu.point,
    _Attendu.point,
    _Attendu.point,
  ], genre: GenreConstruction.arcTroisPoints),
  demiCercle(GroupeOutils.cercles, [
    _Attendu.point,
    _Attendu.point,
  ], genre: GenreConstruction.demiCercle),
  polygone(GroupeOutils.polygones, [_Attendu.point]),
  polygoneRegulier(GroupeOutils.polygones, [
    _Attendu.point,
    _Attendu.point,
  ], nombre: NombreDemande.cotes),
  ellipse(GroupeOutils.coniques, [
    _Attendu.point,
    _Attendu.point,
    _Attendu.point,
  ], genre: GenreConstruction.ellipse),
  hyperbole(GroupeOutils.coniques, [
    _Attendu.point,
    _Attendu.point,
    _Attendu.point,
  ], genre: GenreConstruction.hyperbole),
  parabole(
    GroupeOutils.coniques,
    [_Attendu.point, _Attendu.droite],
    genre: GenreConstruction.parabole,
    ordreLibre: true,
  ),
  coniqueCinqPoints(GroupeOutils.coniques, [
    _Attendu.point,
    _Attendu.point,
    _Attendu.point,
    _Attendu.point,
    _Attendu.point,
  ], genre: GenreConstruction.coniqueCinqPoints),
  symetrieCentrale(GroupeOutils.transformations, [
    _Attendu.image,
    _Attendu.point,
  ], genre: GenreConstruction.symetrieCentrale),
  symetrieAxiale(GroupeOutils.transformations, [
    _Attendu.image,
    _Attendu.droite,
  ], genre: GenreConstruction.symetrieAxiale),
  translation(GroupeOutils.transformations, [
    _Attendu.image,
    _Attendu.vecteur,
  ], genre: GenreConstruction.translation),
  rotation(
    GroupeOutils.transformations,
    [_Attendu.image, _Attendu.point],
    genre: GenreConstruction.rotation,
    nombre: NombreDemande.angle,
  ),
  homothetie(
    GroupeOutils.transformations,
    [_Attendu.image, _Attendu.point],
    genre: GenreConstruction.homothetie,
    nombre: NombreDemande.rapport,
  ),
  longueur(GroupeOutils.mesures, [_Attendu.longueur, _Attendu.pointOuDroite]),
  angle(GroupeOutils.mesures, [
    _Attendu.point,
    _Attendu.point,
    _Attendu.point,
  ], genre: GenreConstruction.angle),
  aire(GroupeOutils.mesures, [_Attendu.surface], genre: GenreConstruction.aire),
  pente(GroupeOutils.mesures, [
    _Attendu.droite,
  ], genre: GenreConstruction.pente),
  curseur(GroupeOutils.avance, []),
  lieu(GroupeOutils.avance, [_Attendu.pointExistant, _Attendu.pointSur]),
  relation(GroupeOutils.avance, [_Attendu.objet, _Attendu.objet]);

  new(
    this.groupe,
    this._attendus, {
    this.genre,
    this.nombre,
    this.ordreLibre = false,
  });

  final GroupeOutils groupe;
  final List<_Attendu> _attendus;

  /// La construction qu'il fait, quand il n'en fait qu'une.
  final GenreConstruction? genre;

  /// Le nombre demandé une fois les objets touchés.
  final NombreDemande? nombre;

  /// Les objets peuvent-ils être touchés dans n'importe quel ordre ?
  final bool ordreLibre;

  /// Combien de touchers il faut ; `null` si c'est à la personne de finir.
  int? get etapes => this == OutilGeo.polygone ? null : _attendus.length;
}

/// La relation demandée entre deux objets, et ce qui a été constaté.
class ConstatRelation {
  const new(this.a, this.b, this.constats);

  final int a;
  final int b;
  final List<Constat> constats;
}

/// La figure en cours et l'outil choisi : tout ce que fait un toucher.
class Atelier extends ChangeNotifier {
  new({this.fichier}) {
    _charger();
    _etats.add(_etat());
  }

  /// Combien de pas on peut annuler.
  static const int _historique = 100;

  File? fichier;
  Figure _figure = Figure();
  OutilGeo _outil = OutilGeo.deplacer;
  final List<int> _choisis = [];
  Map<int, FormeGeo?>? _formes;
  final _etats = <String>[];
  var _etatCourant = 0;
  var _modifie = false;

  /// Grille et axes dessinés, aimantation à la grille.
  bool _grille = true;
  bool _axes = false;
  bool _aimant = true;
  double? _pasAimant;
  double _seuilAimant = 0;

  int? _selection;
  NombreDemande? _nombreAttendu;
  ConstatRelation? _constat;

  OutilGeo get outil => _outil;
  List<int> get choisis => List.unmodifiable(_choisis);
  Figure get figure => _figure;
  bool get estVide => _figure.objets.isEmpty;
  bool get peutAnnuler => _etatCourant > 0;
  bool get peutRetablir => _etatCourant < _etats.length - 1;
  bool get grille => _grille;
  bool get axes => _axes;
  bool get aimant => _aimant;

  /// L'objet touché avec l'outil Déplacer.
  int? get selection => _selection;

  /// Le nombre à demander avant de finir la construction.
  NombreDemande? get nombreAttendu => _nombreAttendu;

  /// Rend le dernier constat, une seule fois.
  ConstatRelation? prendreConstat() {
    final constat = _constat;
    _constat = null;
    return constat;
  }

  Map<int, FormeGeo?> get formes => _formes ??= _figure.calculer();

  /// Les curseurs à montrer.
  Iterable<int> get curseurs => _figure.objets.where(
    (id) =>
        _figure.definition(id) is NombreLibre && _figure.apparence(id).visible,
  );

  /// Tous les nombres, curseurs et mesures.
  Iterable<int> get nombres =>
      _figure.objets.where((id) => formes[id] is NombreGeo);

  set outil(OutilGeo valeur) {
    _outil = valeur;
    _choisis.clear();
    _selection = null;
    _nombreAttendu = null;
    notifyListeners();
  }

  set grille(bool valeur) {
    _grille = valeur;
    notifyListeners();
    _ecrire();
  }

  set axes(bool valeur) {
    _axes = valeur;
    notifyListeners();
    _ecrire();
  }

  set aimant(bool valeur) {
    _aimant = valeur;
    notifyListeners();
    _ecrire();
  }

  /// La maille de la grille à l'écran, et à quelle distance elle attire.
  void reglerAimant(double pas, double seuil) {
    _pasAimant = pas;
    _seuilAimant = seuil;
  }

  (double, double) _aimanter(double x, double y) {
    final pas = _pasAimant;
    if (!_aimant || pas == null) return (x, y);
    final (ax, ay) = (
      (x / pas).roundToDouble() * pas,
      (y / pas).roundToDouble() * pas,
    );
    return (x - ax).abs() <= _seuilAimant && (y - ay).abs() <= _seuilAimant
        ? (ax, ay)
        : (x, y);
  }

  /// L'objet visible le plus proche à moins de [tolerance], les points
  /// d'abord : un point posé sur une droite doit rester attrapable.
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
      if (forme == null || !_figure.apparence(id).visible) return;
      if (filtre != null && !filtre(forme)) return;
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

  /// Le point à attraper en ([x], [y]), libre ou sur un objet.
  int? pointLibreProche(double x, double y, double tolerance) {
    if (_outil != OutilGeo.deplacer) return null;
    final id = objetProche(x, y, tolerance, filtre: (f) => f is PointGeo);
    if (id == null) return null;
    final d = _figure.definition(id);
    return d is PointLibre || d is PointSur ? id : null;
  }

  /// L'objet à faire glisser d'un bloc en ([x], [y]).
  int? objetAGlisser(double x, double y, double tolerance) {
    if (_outil != OutilGeo.deplacer) return null;
    final id = objetProche(x, y, tolerance);
    return id != null && _figure.estTranslatable(id) ? id : null;
  }

  /// Un toucher en ([x], [y]) ; `true` s'il a servi à quelque chose.
  bool toucher(double x, double y, double tolerance) {
    if (_nombreAttendu != null) return false;
    if (_outil == OutilGeo.deplacer || _outil == OutilGeo.curseur) {
      _selection = objetProche(x, y, tolerance);
      notifyListeners();
      return _selection != null;
    }
    if (_outil == OutilGeo.polygone) return _toucherPolygone(x, y, tolerance);
    if (_toucherSegment(x, y, tolerance)) return true;

    final restants = _restants();
    int? trouve;
    for (final attendu in restants) {
      if (attendu == _Attendu.point) continue;
      trouve = _chercher(attendu, x, y, tolerance);
      if (trouve != null) break;
    }
    if (restants.contains(_Attendu.point)) {
      // Un point tout proche passe avant une droite, sauf si on veut l'image
      // d'un objet : c'est alors la droite qu'on a visée.
      final point = objetProche(x, y, tolerance, filtre: (f) => f is PointGeo);
      if (point != null) trouve = point;
      trouve ??= _pointIntelligent(x, y, tolerance);
    }
    if (trouve == null) {
      final creer = restants.any(
        (a) => a == _Attendu.pointOuDroite || a == _Attendu.longueur,
      );
      if (!creer) return false;
      trouve = _pointIntelligent(x, y, tolerance);
    }
    _choisis.add(trouve);
    _peutEtreFinir();
    _valider();
    return true;
  }

  /// Milieu et médiatrice d'un segment : toucher le segment suffit.
  bool _toucherSegment(double x, double y, double tolerance) {
    if (_choisis.isNotEmpty ||
        (_outil != OutilGeo.milieu && _outil != OutilGeo.mediatrice)) {
      return false;
    }
    if (objetProche(x, y, tolerance, filtre: (f) => f is PointGeo) != null) {
      return false;
    }
    final id = objetProche(
      x,
      y,
      tolerance,
      filtre: (f) => f is DroiteGeo && f.estSegment,
    );
    if (id == null) return false;
    final d = _figure.definition(id);
    if (d is! Construite || d.genre != GenreConstruction.segment) return false;
    _choisis.addAll(d.parents);
    _peutEtreFinir();
    _valider();
    return true;
  }

  List<_Attendu> _restants() {
    final attendus = _outil._attendus;
    if (!_outil.ordreLibre) return [attendus[_choisis.length]];
    final restants = List.of(attendus);
    for (final id in _choisis) {
      restants.remove(_genreDe(id));
    }
    return restants;
  }

  _Attendu _genreDe(int id) => formes[id] is PointGeo
      ? _Attendu.point
      : _outil._attendus.firstWhere((a) => a != _Attendu.point);

  bool _convient(_Attendu attendu, FormeGeo forme) => switch (attendu) {
    _Attendu.point ||
    _Attendu.pointExistant ||
    _Attendu.pointSur => forme is PointGeo,
    _Attendu.droite => forme is DroiteGeo,
    _Attendu.vecteur => forme is DroiteGeo && forme.vecteur,
    _Attendu.courbe =>
      forme is DroiteGeo ||
          forme is CercleGeo ||
          forme is ConiqueGeo ||
          forme is PolygoneGeo,
    _Attendu.cercleOuConique => forme is CercleGeo || forme is ConiqueGeo,
    _Attendu.polygone => forme is PolygoneGeo,
    _Attendu.image => forme is! NombreGeo,
    _Attendu.objet => true,
    _Attendu.longueur =>
      forme is PointGeo ||
          (forme is DroiteGeo && forme.estSegment) ||
          forme is CercleGeo ||
          forme is PolygoneGeo,
    _Attendu.pointOuDroite => forme is PointGeo || forme is DroiteGeo,
    _Attendu.surface =>
      forme is PolygoneGeo ||
          (forme is CercleGeo && !forme.estArc) ||
          (forme is ConiqueGeo && forme.genre == GenreConique.ellipse),
  };

  /// [id] peut-il servir à l'étape en cours ? Pour le montrer du doigt.
  bool estCandidat(int id) {
    if (_outil._attendus.isEmpty || _outil == OutilGeo.polygone) return false;
    final forme = formes[id];
    if (forme == null || _choisis.contains(id)) return false;
    return _restants().any((a) {
      if (a == _Attendu.point) return false;
      if (a == _Attendu.pointSur && _figure.definition(id) is! PointSur) {
        return false;
      }
      return _convient(a, forme);
    });
  }

  int? _chercher(_Attendu attendu, double x, double y, double tolerance) {
    final id = objetProche(
      x,
      y,
      tolerance,
      filtre: (f) => _convient(attendu, f),
    );
    if (id == null) return null;
    if (attendu == _Attendu.pointSur && _figure.definition(id) is! PointSur) {
      return null;
    }
    return id;
  }

  /// Le point voulu par un toucher : celui d'un croisement, puis un point sur
  /// l'objet touché, sinon un point libre.
  int _pointIntelligent(double x, double y, double tolerance) {
    final courbes = <int>[];
    final distances = <int, double>{};
    formes.forEach((id, forme) {
      if (forme == null || !_figure.apparence(id).visible) return;
      if (!_convient(_Attendu.courbe, forme)) return;
      final d = distanceA(forme, x, y);
      if (d < tolerance) {
        courbes.add(id);
        distances[id] = d;
      }
    });
    courbes.sort((a, b) => distances[a]!.compareTo(distances[b]!));
    if (courbes.length >= 2) {
      final croisement = _croisement(courbes[0], courbes[1], x, y, tolerance);
      if (croisement != null) return croisement;
    }
    if (courbes.isNotEmpty) {
      final support = courbes.first;
      return _ajouter(
        PointSur(support, parametreSurForme(formes[support]!, x, y)),
      );
    }
    final (ax, ay) = _aimanter(x, y);
    return _ajouter(PointLibre(ax, ay));
  }

  int? _croisement(int a, int b, double x, double y, double tolerance) {
    final points = intersections(formes[a]!, formes[b]!);
    const genres = [
      GenreConstruction.intersection1,
      GenreConstruction.intersection2,
      GenreConstruction.intersection3,
      GenreConstruction.intersection4,
    ];
    final ici = PointGeo(x, y);
    var meilleure = tolerance;
    int? indice;
    for (var i = 0; i < points.length && i < genres.length; i++) {
      final d = points[i].distance(ici);
      if (d < meilleure) {
        meilleure = d;
        indice = i;
      }
    }
    return indice == null ? null : _ajouter(Construite(genres[indice], [a, b]));
  }

  int _ajouter(Definition definition, {Apparence? apparence}) {
    final id = _figure.ajouter(definition, apparence: apparence);
    _formes = null;
    return id;
  }

  bool _toucherPolygone(double x, double y, double tolerance) {
    final premier = _choisis.isEmpty ? null : _choisis.first;
    final proche = objetProche(x, y, tolerance, filtre: (f) => f is PointGeo);
    if (proche != null && proche == premier && _choisis.length >= 3) {
      _ajouter(Construite(GenreConstruction.polygone, List.of(_choisis)));
      _choisis.clear();
    } else if (proche != null && _choisis.contains(proche)) {
      return false;
    } else {
      _choisis.add(proche ?? _pointIntelligent(x, y, tolerance));
    }
    _valider();
    return true;
  }

  void _peutEtreFinir() {
    final fini =
        _choisis.length == _outil._attendus.length ||
        (_outil == OutilGeo.longueur && formes[_choisis.first] is! PointGeo);
    if (!fini) return;
    if (_outil.nombre != null) {
      _nombreAttendu = _outil.nombre;
      return;
    }
    _construire();
    _choisis.clear();
  }

  /// Les objets touchés, dans l'ordre que la construction attend.
  List<int> _ordonnes() {
    if (!_outil.ordreLibre) return List.of(_choisis);
    final premierPoint = _outil._attendus.first == _Attendu.point;
    final points = _choisis.where((id) => formes[id] is PointGeo);
    final autres = _choisis.where((id) => formes[id] is! PointGeo);
    return premierPoint ? [...points, ...autres] : [...autres, ...points];
  }

  void _construire() {
    final c = _ordonnes();
    switch (_outil) {
      case OutilGeo.intersection:
        _creerIntersections(c);
      case OutilGeo.tangente:
        _ajouter(Construite(GenreConstruction.tangente1, c));
        final (courbe, point) = (formes[c.first], formes[c.last]);
        final surCourbe =
            courbe != null &&
            point != null &&
            relationsEntre(courbe, point).contains(RelationGeo.appartient);
        // Sur la courbe, il n'y a qu'une tangente.
        if (!surCourbe) _ajouter(Construite(GenreConstruction.tangente2, c));
      case OutilGeo.gomme:
        _figure.retirer(c.single);
        _formes = null;
      case OutilGeo.longueur:
        _ajouter(
          c.length == 1
              ? Construite(GenreConstruction.longueur, c)
              : Construite(GenreConstruction.distance, c),
        );
      case OutilGeo.lieu:
        _ajouter(Lieu(c[0], c[1]));
      case OutilGeo.relation:
        _constat = ConstatRelation(c[0], c[1], _figure.constater(c[0], c[1]));
      case _:
        final genre = _outil.genre;
        if (genre != null) _ajouter(Construite(genre, c));
    }
  }

  void _creerIntersections(List<int> c) {
    if (c[0] == c[1]) return;
    final (a, b) = (formes[c[0]], formes[c[1]]);
    final combien = switch ((a, b)) {
      (DroiteGeo(), DroiteGeo()) => 1,
      (CercleGeo(), CercleGeo()) ||
      (DroiteGeo(), CercleGeo()) ||
      (CercleGeo(), DroiteGeo()) ||
      (DroiteGeo(), ConiqueGeo()) ||
      (ConiqueGeo(), DroiteGeo()) => 2,
      _ => 4,
    };
    const genres = [
      GenreConstruction.intersection1,
      GenreConstruction.intersection2,
      GenreConstruction.intersection3,
      GenreConstruction.intersection4,
    ];
    for (final genre in genres.take(combien)) {
      _ajouter(Construite(genre, List.of(c)));
    }
  }

  /// Termine la construction avec ce nombre, ou ce nombre de côtés.
  void donnerValeur(double valeur) {
    final attendu = _nombreAttendu;
    if (attendu == null) return;
    if (attendu == NombreDemande.cotes) {
      _finirPolygoneRegulier(valeur.round());
    } else {
      final n = _ajouter(
        NombreLibre(valeur),
        apparence: Apparence(visible: false),
      );
      _finirAvecNombre(n);
    }
  }

  /// Termine la construction avec le curseur ou la mesure [id].
  void donnerNombre(int id) {
    if (_nombreAttendu != null) _finirAvecNombre(id);
  }

  /// Renonce au nombre demandé, et à ce qui était touché pour lui.
  void renoncerAuNombre() {
    _nombreAttendu = null;
    _choisis.clear();
    notifyListeners();
  }

  void _finirAvecNombre(int nombre) {
    _ajouter(Construite(_outil.genre!, [..._ordonnes(), nombre]));
    _nombreAttendu = null;
    _choisis.clear();
    _valider();
  }

  void _finirPolygoneRegulier(int cotes) {
    final g = _ajouter(
      Construite(
        GenreConstruction.polygoneRegulier,
        List.of(_choisis),
        parametre: cotes,
      ),
    );
    for (var k = 2; k < cotes; k++) {
      _ajouter(Construite(GenreConstruction.sommet, [g], parametre: k));
    }
    _nombreAttendu = null;
    _choisis.clear();
    _valider();
  }

  /// Ce que donnerait la construction si le doigt restait en ([x], [y]) :
  /// seulement quand il ne manque que ce point.
  FormeGeo? apercu(double x, double y) {
    if (_outil.nombre != null) return null;
    if (_outil == OutilGeo.polygone) {
      if (_choisis.isEmpty) return null;
      final dernier = formes[_choisis.last];
      return dernier is PointGeo
          ? DroiteGeo.par(dernier, PointGeo(x, y), segment: true)
          : null;
    }
    final genre = _outil.genre;
    if (genre == null || _choisis.length != _outil._attendus.length - 1) {
      return null;
    }
    if (!_restants().contains(_Attendu.point)) return null;
    const fantome = -1;
    final parents = _outil.ordreLibre
        ? [..._choisis.where((id) => formes[id] is! PointGeo), fantome]
        : [..._choisis, fantome];
    return Construite(
      genre,
      parents,
    ).calculer((id) => id == fantome ? PointGeo(x, y) : formes[id]);
  }

  /// Place un point ou un vecteur déclaré sur la Feuille. Un point du même nom
  /// se déplace au lieu de se doubler. S'annule d'un coup.
  void placerObjet(ObjetLu objet) {
    switch (objet) {
      case PointLu(:final nom, :final x, :final y):
        _pointNomme(nom, x, y);
      case VecteurLu(:final nom, :final x, :final y):
        final (origine, extremite) = nom.length == 2
            ? (nom[0], nom[1])
            : ('O', nom.toUpperCase());
        final depart = _pointExistant(origine);
        final a = depart ?? _pointNomme(origine, 0, 0);
        final forme = formes[a];
        final (ax, ay) = forme is PointGeo ? (forme.x, forme.y) : (0.0, 0.0);
        final b = _pointNomme(extremite, ax + x, ay + y);
        final deja = _figure.objets.any((id) {
          final d = _figure.definition(id);
          return d is Construite &&
              d.genre == GenreConstruction.vecteur &&
              d.parents.length == 2 &&
              d.parents[0] == a &&
              d.parents[1] == b;
        });
        if (!deja) {
          final id = _ajouter(Construite(GenreConstruction.vecteur, [a, b]));
          if (nom.length == 1) _figure.renommer(id, nom);
        }
    }
    _formes = null;
    _valider();
  }

  /// Construit dans la Figure ce que commande la Feuille : `cercle(A;2)`,
  /// `(AB)`… Les points doivent y être ; rend `false` sinon. S'annule d'un
  /// coup.
  bool construire(CommandeGeo commande) {
    final ids = [for (final n in commande.points) _pointExistant(n)];
    if (ids.contains(null)) return false;
    final parents = ids.cast<int>();
    final int id;
    switch (commande.genre) {
      case GenreCommande.cercleRayon:
        final r = _ajouter(
          NombreLibre(commande.rayon!),
          apparence: Apparence(visible: false),
        );
        id = _ajouter(
          Construite(GenreConstruction.cercleRayon, [...parents, r]),
        );
      case final genre:
        final construction = switch (genre) {
          GenreCommande.droite => GenreConstruction.droite,
          GenreCommande.segment => GenreConstruction.segment,
          GenreCommande.demiDroite => GenreConstruction.demiDroite,
          GenreCommande.cercle => GenreConstruction.cercle,
          GenreCommande.milieu => GenreConstruction.milieu,
          GenreCommande.mediatrice => GenreConstruction.mediatrice,
          GenreCommande.cercleRayon => GenreConstruction.cercleRayon,
        };
        final deja = _figure.objets.where((o) {
          final d = _figure.definition(o);
          return d is Construite &&
              d.genre == construction &&
              d.parents.join(',') == parents.join(',');
        }).firstOrNull;
        id = deja ?? _ajouter(Construite(construction, parents));
    }
    final nom = commande.nom;
    if (nom != null) _figure.renommer(id, nom);
    _formes = null;
    _valider();
    return true;
  }

  int? _pointExistant(String nom) {
    for (final id in _figure.objets) {
      if (_figure.categorie(id) == CategorieGeo.point &&
          _figure.apparence(id).nom == nom) {
        return id;
      }
    }
    return null;
  }

  int _pointNomme(String nom, double x, double y) {
    final existant = _pointExistant(nom);
    if (existant != null) {
      if (_figure.definition(existant) is PointLibre) {
        _figure.deplacer(existant, x, y);
      }
      _formes = null;
      return existant;
    }
    final id = _ajouter(PointLibre(x, y));
    _figure.renommer(id, nom);
    _formes = null;
    return id;
  }

  /// Crée un curseur de valeur [valeur].
  int ajouterCurseur(double valeur, {double? min, double? max}) {
    final id = _ajouter(NombreLibre(valeur, min: min, max: max));
    _valider();
    return id;
  }

  /// Déplace un point ; à conclure par [terminerGeste].
  void deplacer(int id, double x, double y) {
    final (ax, ay) = _figure.definition(id) is PointLibre
        ? _aimanter(x, y)
        : (x, y);
    _figure.deplacer(id, ax, ay);
    _bouger();
  }

  /// Fait glisser un objet d'un bloc ; à conclure par [terminerGeste].
  void translater(int id, double dx, double dy) {
    _figure.translater(id, dx, dy);
    _bouger();
  }

  /// Donne une valeur à un curseur ; à conclure par [terminerGeste].
  void fixerNombre(int id, double valeur) {
    _figure.fixerNombre(id, valeur);
    _bouger();
  }

  void _bouger() {
    _modifie = true;
    _formes = null;
    notifyListeners();
  }

  /// Fin d'un glissement : un seul pas à annuler, et une seule écriture.
  void terminerGeste() {
    if (_modifie) _valider();
  }

  /// Place un point libre à ces coordonnées, sans aimant.
  void placer(int id, double x, double y) {
    _figure.deplacer(id, x, y);
    _valider();
  }

  /// Règle les bornes d'un curseur.
  void bornerCurseur(int id, double min, double max) {
    if (min >= max) return;
    final n = _figure.definition(id) as NombreLibre;
    n
      ..min = min
      ..max = max
      ..valeur = n.valeur.clamp(min, max);
    _valider();
  }

  /// Change l'apparence de [id].
  void modifierApparence(int id, void Function(Apparence) changement) {
    changement(_figure.apparence(id));
    _valider();
  }

  /// Renomme [id] ; `false` si le nom est vide ou déjà pris.
  bool renommer(int id, String nom) {
    final fait = _figure.renommer(id, nom);
    if (fait) _valider();
    return fait;
  }

  /// Retire [id] et ce qui en dépend.
  void retirer(int id) {
    _figure.retirer(id);
    if (_selection != null && !_figure.objets.contains(_selection)) {
      _selection = null;
    }
    _choisis.clear();
    _valider();
  }

  /// Oublie l'objet touché.
  void deselectionner() {
    _selection = null;
    notifyListeners();
  }

  /// Passe à la figure gardée dans [autre], ou à une figure vide s'il n'existe
  /// pas encore. L'annulation ne remonte pas à la figure d'avant.
  void changerDeFichier(File? autre) {
    fichier = autre;
    _figure = Figure();
    _outil = OutilGeo.deplacer;
    _choisis.clear();
    _selection = null;
    _nombreAttendu = null;
    _charger();
    _formes = null;
    _etats
      ..clear()
      ..add(_etat());
    _etatCourant = 0;
    notifyListeners();
  }

  /// Revient d'un pas en arrière.
  void annuler() {
    if (!peutAnnuler) return;
    _etatCourant--;
    _restaurer();
  }

  /// Refait ce qui vient d'être annulé.
  void retablir() {
    if (!peutRetablir) return;
    _etatCourant++;
    _restaurer();
  }

  /// Efface tout ; on peut annuler.
  void effacer() {
    _figure = Figure();
    _selection = null;
    _choisis.clear();
    _valider();
  }

  void _restaurer() {
    _figure = Figure.depuisJson(
      jsonDecode(_etats[_etatCourant]) as List<dynamic>,
    );
    _selection = null;
    _nombreAttendu = null;
    _choisis.clear();
    _formes = null;
    notifyListeners();
    _ecrire();
  }

  String _etat() => jsonEncode(_figure.versJson());

  void _valider() {
    _modifie = false;
    _formes = null;
    final etat = _etat();
    if (etat != _etats[_etatCourant]) {
      _etats
        ..removeRange(_etatCourant + 1, _etats.length)
        ..add(etat);
      if (_etats.length > _historique) _etats.removeAt(0);
      _etatCourant = _etats.length - 1;
    }
    notifyListeners();
    _ecrire();
  }

  void _charger() {
    final fichier = this.fichier;
    if (fichier == null || !fichier.existsSync()) return;
    try {
      final json = jsonDecode(fichier.readAsStringSync());
      // Avant la 0.4 : la seule liste des objets.
      if (json is List<dynamic>) {
        _figure = Figure.depuisJson(json);
        return;
      }
      final carte = json as Map<String, dynamic>;
      _figure = Figure.depuisJson(carte['objets'] as List<dynamic>);
      _grille = carte['grille'] as bool? ?? true;
      _axes = carte['axes'] as bool? ?? false;
      _aimant = carte['aimant'] as bool? ?? true;
    } on Object {
      // Un fichier abîmé est mis de côté, jamais écrasé.
      fichier.renameSync('${fichier.path}.illisible');
    }
  }

  void _ecrire() {
    fichier?.writeAsStringSync(
      jsonEncode({
        'grille': _grille,
        'axes': _axes,
        'aimant': _aimant,
        'objets': _figure.versJson(),
      }),
    );
  }
}
