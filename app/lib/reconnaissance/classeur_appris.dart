import 'dart:async';

import 'dart:ui';

import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/reconnaissance/classeur_signes.dart';
import 'package:fikajiana/reconnaissance/exemples_personnels.dart';

/// Le classeur de l'application (ADR 0041) : les corrections de la personne
/// d'abord, puis les gabarits ; le petit modèle (ADR 0038, 0040) répond
/// quand les gabarits doutent et qu'il est sûr de lui.
///
/// Chaque signe se classe dès qu'il est fini ([preparer]) et son verdict
/// reste en cache : la lecture de la ligne ne fait plus que le relire.
class ClasseurAppris extends ClasseurSignes {
  new({this.exemples, this.modele, this.base = const ClasseurGabarits()}) {
    exemples?.addListener(_imposes.clear);
  }

  final ExemplesPersonnels? exemples;

  /// Le petit modèle par signe (ADR 0038), une fois chargé ; `null` : les
  /// gabarits seuls, comme avant.
  ClasseurSignes? modele;
  final ClasseurSignes base;

  /// Seuil de probabilité et écart au second pour croire le modèle, là où
  /// les gabarits doutent. Réglés sur le Pad 7 (`banc/banc_lecture.dart`)
  /// avec les séances que l'entraînement n'a jamais vues : à 0,7, 18 signes
  /// pris sur 33 doutes, tous justes ; à 0,5, une erreur. Échantillon
  /// petit : à revoir avec l'écriture collectée.
  static const double seuilProba = 0.7;
  static const double ecartProba = 0.3;

  /// Au-delà, le cache repart de zéro : une feuille n'en a jamais autant.
  static const int _maximum = 4000;

  final _signes = <String, Map<String, double>?>{};
  final _chiffres = <String, String?>{};
  final _capitales = <String, String?>{};
  final _imposes = <String, String?>{};
  final _classements = <String, Classement>{};
  final _enCours = <String, Future<Classement>>{};

  /// Combien de verdicts ont été lus dans le cache, et combien calculés :
  /// pour le journal `fikajiana.lecture`.
  int trouves = 0;
  int calcules = 0;

  void _borner() {
    if (_signes.length + _chiffres.length + _capitales.length < _maximum) {
      return;
    }
    _signes.clear();
    _chiffres.clear();
    _capitales.clear();
    _classements.clear();
  }

  T _cache<T>(Map<String, T> cache, String cle, T Function() calcul) {
    if (cache.containsKey(cle)) {
      trouves++;
      return cache[cle] as T;
    }
    calcules++;
    _borner();
    return cache[cle] = calcul();
  }

  /// Le verdict du modèle sur une classe déjà calculée, avec ses règles de
  /// doute : la famille entière quand les premières se confondent.
  static Map<String, double>? deciderProbas(Classement c) {
    if (c.isEmpty) return null;
    final (premiere, p) = c.first;
    final second = c.length > 1 ? c[1].$2 : 0.0;
    if (p < seuilProba || p - second < ecartProba) return null;
    if (!classesLues.hasMatch(premiere)) return null;
    return {premiere: 1 - p};
  }

  /// Ce que la lecture au tracé sait écrire ; le reste va à Pix2Text.
  static final classesLues = RegExp(r"^([0-9A-Za-z+\-=()']|\\pi|\\times)$");

  /// Le verdict du modèle, s'il a déjà classé ce signe.
  Map<String, double>? _modele(String cle) {
    final appris = _classements[cle];
    return modele == null || appris == null ? null : deciderProbas(appris);
  }

  @override
  String? impose(List<Trait> signe) {
    final e = exemples;
    if (e == null || e.liste.isEmpty) return null;
    return _cache(
      _imposes,
      cleDuSigne(signe),
      () => e.corrige(signe) ?? e.reconnaitre(signe),
    );
  }

  @override
  Map<String, double>? signe(
    List<Trait> signe, {
    required double hauteurLigne,
  }) {
    final cle = cleDuSigne(signe);
    return _cache(
          _signes,
          cle,
          () => base.signe(signe, hauteurLigne: hauteurLigne),
        ) ??
        _modele(cle);
  }

  @override
  String? chiffre(List<Trait> signe) {
    final cle = cleDuSigne(signe);
    final lu = _cache(_chiffres, cle, () => base.chiffre(signe));
    if (lu != null) return lu;
    final s = _modele(cle)?.keys.single;
    return s != null && RegExp(r'^\d$').hasMatch(s) ? s : null;
  }

  @override
  String? capitale(List<Trait> signe) {
    final cle = cleDuSigne(signe);
    final lu = _cache(_capitales, cle, () => base.capitale(signe));
    if (lu != null) return lu;
    final s = _modele(cle)?.keys.single;
    return s != null && RegExp(r'^[A-Z]$').hasMatch(s) ? s : null;
  }

  /// Le verdict de ce signe est-il déjà là ?
  bool connu(List<Trait> signe) {
    final cle = cleDuSigne(signe);
    return _signes.containsKey(cle) ||
        (modele != null && _classements.containsKey(cle));
  }

  /// Classe [signe] tout de suite, pour que la lecture de sa ligne le
  /// trouve prêt. Rend `true` si le signe est sûr.
  Future<bool> preparer(List<Trait> signe, {required Rect caseLigne}) async {
    final cle = cleDuSigne(signe);
    if (modele != null && !_classements.containsKey(cle)) {
      final chrono = Stopwatch()..start();
      await classer(signe, caseLigne: caseLigne);
      msModele += chrono.elapsedMicroseconds / 1000;
      signesModele++;
    }
    return impose(signe) != null ||
        this.signe(signe, hauteurLigne: caseLigne.height) != null;
  }

  /// Le temps passé dans le modèle, et pour combien de signes : pour le
  /// journal.
  double msModele = 0;
  int signesModele = 0;

  @override
  Future<Classement> classer(
    List<Trait> signe, {
    required Rect caseLigne,
    int combien = 3,
  }) async {
    final cle = cleDuSigne(signe);
    final source = modele ?? base;
    final deja = _classements[cle];
    final Classement classement;
    if (deja != null) {
      classement = deja;
    } else {
      final enCours = _enCours[cle] ??= source.classer(
        signe,
        caseLigne: caseLigne,
        combien: 8,
      );
      classement = await enCours;
    }
    unawaited(_enCours.remove(cle));
    if (modele != null) _classements[cle] = classement;
    // Les corrections de la personne d'abord, sans doublon.
    final vus = <String>{};
    final propres = [
      for (final (c, d)
          in exemples?.voisins(signe) ?? const <(String, double)>[])
        if (d <= ExemplesPersonnels.seuil) (c, 1.0),
    ];
    return [
      for (final (c, p) in [...propres, ...classement])
        if (vus.add(c)) (c, p),
    ].take(combien).toList();
  }

  /// Une correction vient d'arriver : les verdicts en cache peuvent être
  /// faux.
  void oublier() {
    _signes.clear();
    _chiffres.clear();
    _capitales.clear();
    _imposes.clear();
    _classements.clear();
  }
}
