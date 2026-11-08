import 'dart:async';

import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/reconnaissance/classeur_signes.dart';
import 'package:fikajiana/reconnaissance/exemples_personnels.dart';

/// Le classeur de l'application (ADR 0041) : les corrections de la personne
/// d'abord, puis le petit modèle s'il est là, sinon les gabarits.
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

  /// Seuil de probabilité et écart au second pour croire le modèle.
  /// Provisoires : à régler sur le jeu de validation de `entrainement/`.
  static const double seuilProba = 0.9;
  static const double ecartProba = 0.5;

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
    return {premiere: 1 - p};
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
    final appris = _classements[cle];
    if (modele != null && appris != null) return deciderProbas(appris);
    return _cache(
      _signes,
      cle,
      () => base.signe(signe, hauteurLigne: hauteurLigne),
    );
  }

  @override
  String? chiffre(List<Trait> signe) {
    final cle = cleDuSigne(signe);
    final appris = _classements[cle];
    if (modele != null && appris != null) {
      final s = deciderProbas(appris)?.keys.single;
      return s != null && RegExp(r'^\d$').hasMatch(s) ? s : null;
    }
    return _cache(_chiffres, cle, () => base.chiffre(signe));
  }

  @override
  String? capitale(List<Trait> signe) {
    final cle = cleDuSigne(signe);
    final appris = _classements[cle];
    if (modele != null && appris != null) {
      final s = deciderProbas(appris)?.keys.single;
      return s != null && RegExp(r'^[A-Z]$').hasMatch(s) ? s : null;
    }
    return _cache(_capitales, cle, () => base.capitale(signe));
  }

  /// Le verdict de ce signe est-il déjà là ?
  bool connu(List<Trait> signe) {
    final cle = cleDuSigne(signe);
    return _signes.containsKey(cle) ||
        (modele != null && _classements.containsKey(cle));
  }

  /// Classe [signe] tout de suite, pour que la lecture de sa ligne le
  /// trouve prêt. Rend `true` si le signe est sûr.
  Future<bool> preparer(
    List<Trait> signe, {
    required double hauteurLigne,
  }) async {
    if (modele != null) {
      await classer(signe, hauteurLigne: hauteurLigne);
    }
    return impose(signe) != null ||
        this.signe(signe, hauteurLigne: hauteurLigne) != null;
  }

  @override
  Future<Classement> classer(
    List<Trait> signe, {
    required double hauteurLigne,
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
        hauteurLigne: hauteurLigne,
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
