import 'dart:math' as math;
import 'dart:ui';

import 'package:fikajiana/encre/filtre_un_euro.dart';
import 'package:fikajiana/encre/formes.dart';
import 'package:fikajiana/encre/rature.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

/// Un point d'un trait, en pixels logiques, avec la pression du stylet.
class PointEncre {
  const new(this.x, this.y, this.pression, {this.tempsMs});

  factory depuisJson(List<dynamic> json) => PointEncre(
    (json[0] as num).toDouble(),
    (json[1] as num).toDouble(),
    (json[2] as num).toDouble(),
    tempsMs: json.length > 3 ? (json[3] as num).toDouble() : null,
  );

  final double x;
  final double y;
  final double pression;
  final double? tempsMs;

  Offset get position => Offset(x, y);

  List<double> versJson() => [x, y, pression, ?tempsMs];
}

/// Un trait : les points **bruts**, qui servent à la reconnaissance, et ce qui
/// est dessiné, lissé ou remplacé par une forme nette.
class Trait {
  new(PointEncre premier, {this.stylo = 0, this.auStylet = false, int? id})
    : id = id ?? _idSuivant++,
      points = [premier],
      _lisses = [] {
    if (this.id >= _idSuivant) _idSuivant = this.id + 1;
    _ajouterLisse(premier);
  }

  factory depuisDocument(Map<String, dynamic> json) {
    final bruts = (json['points'] as List<dynamic>).cast<List<dynamic>>();
    final trait = Trait(
      PointEncre.depuisJson(bruts.first),
      stylo: json['stylo'] as int? ?? 0,
      auStylet: json['auStylet'] as bool? ?? false,
      id: json['id'] as int?,
    );
    bruts.skip(1).map(PointEncre.depuisJson).forEach(trait._ajouter);
    final forme = json['forme'] as Map<String, dynamic>?;
    trait
      ..forme = forme == null ? null : formeDepuisJson(forme)
      .._terminer();
    return trait;
  }

  new _avecForme(Trait source, Forme this.forme)
    : id = source.id,
      points = source.points,
      _lisses = source._lisses,
      stylo = source.stylo,
      auStylet = source.auStylet;

  /// Le même trait, ailleurs : même identifiant, pour rester dans son bloc.
  /// L'ancien reste intact : annuler le retrouve.
  new deplace(Trait source, this.points)
    : id = source.id,
      stylo = source.stylo,
      auStylet = source.auStylet,
      _lisses = [] {
    points.forEach(_ajouterLisse);
    _termine = true;
  }

  /// Identifiant stable : désigne ce trait dans un bloc et dans la sauvegarde.
  final int id;
  static int _idSuivant = 0;

  final List<PointEncre> points;
  final List<PointVector> _lisses;
  final int stylo;
  final bool auStylet;
  Forme? forme;

  final _filtre = FiltreUnEuro();
  Path? _contour;
  var _termine = false;

  void _ajouterLisse(PointEncre p) {
    final position = _filtre.filtrer(p.position, p.tempsMs);
    _lisses.add(
      PointVector(position.dx, position.dy, pressionNormalisee(p.pression)),
    );
  }

  void _ajouter(PointEncre p) {
    points.add(p);
    _ajouterLisse(p);
    _contour = null;
  }

  void _terminer() {
    _termine = true;
    _contour = null;
  }

  Map<String, dynamic> versDocument() => {
    'id': id,
    'stylo': stylo,
    'auStylet': auStylet,
    'points': [for (final p in points) p.versJson()],
    if (forme != null) 'forme': formeVersJson(forme!),
  };

  /// Ce que touche la gomme : la forme si le trait en est devenu une.
  List<Offset> get pointsVisibles =>
      forme?.echantillons() ?? [for (final p in points) p.position];

  /// Contour rempli du trait, gardé en cache dès que le trait ne bouge plus.
  Path get contour => _contour ??= _calculerContour();

  Path _calculerContour() {
    final forme = this.forme;
    final entree = forme == null
        ? _lisses
        : [for (final p in forme.echantillons()) PointVector(p.dx, p.dy, 0.5)];
    final contour = getStroke(
      entree,
      options: StrokeOptions(
        size: _taille,
        // Au stylet, sa pression ; au doigt, la vitesse fait le plein et le
        // délié, comme une plume. Une forme nette reste régulière.
        thinning: forme != null
            ? 0
            : auStylet
            ? 0.55
            : 0.5,
        smoothing: 0.5,
        streamline: forme != null
            ? 0
            : auStylet
            ? 0.35
            : 0.45,
        simulatePressure: forme == null && !auStylet,
        start: StrokeEndOptions.start(
          taperEnabled: forme == null,
          customTaper: _taille * 1.5,
        ),
        end: StrokeEndOptions.end(
          taperEnabled: forme == null && _termine,
          customTaper: _taille * 3,
        ),
        isComplete: _termine || forme != null,
      ),
    );
    return _cheminFerme(contour);
  }
}

const double _taille = 4;

/// Pression relevée sur le Pad 7 : médiane 0,11, 99 % sous 0,25, sur 30 132
/// points d'Antsa. On l'étale sur 0 à 1 ; à revoir sur d'autres stylets.
double pressionNormalisee(double pression) =>
    math.sqrt((pression / 0.25).clamp(0.0, 1.0));

Path _cheminFerme(List<Offset> contour) {
  final chemin = Path();
  if (contour.isEmpty) return chemin;
  chemin.moveTo(contour.first.dx, contour.first.dy);
  for (var i = 1; i < contour.length - 1; i++) {
    final (a, b) = (contour[i], contour[i + 1]);
    chemin.quadraticBezierTo(a.dx, a.dy, (a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
  }
  return chemin..close();
}

/// Ce qu'une rature vient d'emporter, pour le faire disparaître en douceur.
class Rature {
  const new(this.trait, this.emportes);

  final Trait trait;
  final List<Trait> emportes;
}

/// Traits écrits sur une feuille, avec annuler et refaire.
class Encre {
  /// Prévenu quand des traits changent de place : (avant, après).
  void Function(List<(Trait, Trait)>)? surDeplacement;

  final List<Trait> _traits = [];
  final List<List<Trait>> _annulations = [];
  final List<List<Trait>> _retablissements = [];

  List<Trait> get traits => List.unmodifiable(_traits);
  bool get estVide => _traits.isEmpty;
  DateTime? _finDernierTrait;

  bool get peutAnnuler => _annulations.isNotEmpty;
  bool get peutRefaire => _retablissements.isNotEmpty;

  void _memoriser() {
    _annulations.add([..._traits]);
    _retablissements.clear();
  }

  void commencer(PointEncre point, {int stylo = 0, bool auStylet = false}) {
    _memoriser();
    _traits.add(Trait(point, stylo: stylo, auStylet: auStylet));
  }

  void prolonger(PointEncre point) {
    if (_traits.isEmpty || _traits.last.forme != null) return;
    _traits.last._ajouter(point);
  }

  /// Retire le trait en cours sans laisser d'étape à annuler : un second doigt
  /// vient de montrer que ce n'était pas de l'écriture.
  void abandonnerDernierTrait() {
    if (_traits.isEmpty || _annulations.isEmpty) return;
    _traits.removeLast();
    _annulations.removeLast();
  }

  /// Le stylet est levé : le trait reçoit sa fin définitive.
  void terminer() {
    _finDernierTrait = DateTime.now();
    if (_traits.isNotEmpty) _traits.last._terminer();
  }

  /// Remplace le dernier trait par une forme nette, si c'en est une. S'annule.
  bool formerDernierTrait() {
    if (_traits.isEmpty || _traits.last.forme != null) return false;
    final dernier = _traits.last;
    final forme = reconnaitreForme([
      for (final p in dernier.points) p.position,
    ]);
    if (forme == null) return false;
    _memoriser();
    _traits.last = Trait._avecForme(dernier, forme);
    return true;
  }

  /// Un bouton posé sur la feuille vient d'être touché : le petit point que ce
  /// toucher a laissé dans l'encre n'est pas de l'écriture.
  ///
  /// Sans effet si le dernier trait n'est pas ce point : un doigt ignoré, ou le
  /// lecteur d'écran, touchent le bouton sans rien écrire.
  void retirerPointDuToucher() {
    final fin = _finDernierTrait;
    if (fin == null || _traits.isEmpty) return;
    if (DateTime.now().difference(fin) > const Duration(milliseconds: 200)) {
      return;
    }
    final points = [for (final p in _traits.last.points) p.position];
    if (points.any((p) => (p - points.first).distance > 18)) return;
    abandonnerDernierTrait();
  }

  /// Retire les traits [ids] d'un coup. S'annule.
  void retirerTraits(Set<int> ids) {
    if (!_traits.any((t) => ids.contains(t.id))) return;
    _memoriser();
    _traits.removeWhere((t) => ids.contains(t.id));
  }

  /// Le dernier trait est-il une rature sur quelque chose ? Elle s'efface alors
  /// avec ce qu'elle couvre, plus les traits [enPlus]. Le tout s'annule d'un
  /// coup : `commencer` a déjà mémorisé l'état d'avant la rature.
  Rature? raturerDernierTrait({Set<int> Function(Rect)? enPlus}) {
    if (_traits.isEmpty || _traits.last.forme != null) return null;
    final dernier = _traits.last;
    final points = [for (final p in dernier.points) p.position];
    final franche = estRature(points);
    if (!franche && !estRatureHesitante(points)) return null;
    final zone = cadreDeRature(points);
    if (!franche &&
        !_traits.any(
          (t) => !identical(t, dernier) && couvreBien(t.pointsVisibles, zone),
        )) {
      return null;
    }
    final suppl = enPlus?.call(zone) ?? const <int>{};
    final emportes = [
      for (final t in _traits)
        if (!identical(t, dernier) &&
            (suppl.contains(t.id) || estSousRature(t.pointsVisibles, zone)))
          t,
    ];
    // Rien dessous : c'est de l'écriture, on n'y touche pas.
    if (emportes.isEmpty && suppl.isEmpty) return null;
    _traits.removeWhere((t) => identical(t, dernier) || emportes.contains(t));
    return Rature(dernier, emportes);
  }

  /// Remplace des traits par les mêmes, déplacés. S'annule.
  void remplacer(Map<int, Trait> nouveaux) {
    if (nouveaux.isEmpty) return;
    _memoriser();
    final paires = <(Trait, Trait)>[];
    for (var i = 0; i < _traits.length; i++) {
      final nouveau = nouveaux[_traits[i].id];
      if (nouveau != null) {
        paires.add((_traits[i], nouveau));
        _traits[i] = nouveau;
      }
    }
    surDeplacement?.call(paires);
  }

  /// Retire les traits qui passent à moins de [rayon] de [position].
  void gommer(Offset position, double rayon) {
    bool touche(Trait trait) =>
        trait.pointsVisibles.any((p) => (p - position).distance <= rayon);
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

  /// Le contenu, pour la sauvegarde, sans l'historique d'annulation.
  List<Map<String, dynamic>> versDocument() => [
    for (final trait in _traits) trait.versDocument(),
  ];

  void chargerDocument(List<dynamic> document) {
    _annulations.clear();
    _retablissements.clear();
    _traits
      ..clear()
      ..addAll(document.cast<Map<String, dynamic>>().map(Trait.depuisDocument));
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
