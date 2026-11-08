import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:fikajiana/comprendre/signes.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/reconnaissance/classes_signes.dart';
import 'package:fikajiana/reconnaissance/classeur_signes.dart';
import 'package:flutter/foundation.dart';

/// Un signe que la personne a corrigé : ses traits et ce qu'il est.
class ExemplePersonnel {
  const new({
    required this.classe,
    required this.traits,
    required this.cle,
    required this.quand,
    this.auStylet = true,
  });

  factory depuisJson(Map<String, dynamic> json) => ExemplePersonnel(
    classe: json['classe'] as String,
    cle: json['cle'] as String? ?? '',
    quand: DateTime.parse(json['quand'] as String),
    auStylet: json['auStylet'] as bool? ?? true,
    traits: [
      for (final t in json['traits'] as List<dynamic>)
        [
          for (final p in t as List<dynamic>)
            PointEncre.depuisJson(p as List<dynamic>),
        ],
    ],
  );

  /// Le LaTeX du signe, comme la lecture au tracé l'écrit.
  final String classe;

  /// Les points bruts, en dp de la page.
  final List<List<PointEncre>> traits;

  /// [cleDuSigne] des traits corrigés : les mêmes traits relus prennent
  /// cette classe, sans calcul.
  final String cle;
  final DateTime quand;
  final bool auStylet;

  List<List<Offset>> get dessin => [
    for (final t in traits) [for (final p in t) p.position],
  ];

  Map<String, dynamic> versJson() => {
    'classe': classe,
    'cle': cle,
    'quand': quand.toIso8601String(),
    'auStylet': auStylet,
    'traits': [
      for (final t in traits) [for (final p in t) p.versJson()],
    ],
  };
}

/// Les corrections de la personne, gardées sur l'appareil, jamais envoyées
/// (ADR 0038, 0039). Un plus proche voisin les relit : un signe tout près
/// d'un exemple, et loin des exemples d'autres classes, en prend la classe.
class ExemplesPersonnels extends ChangeNotifier {
  new({this.fichier});

  /// `null` : en mémoire seulement (tests).
  final File? fichier;
  final List<ExemplePersonnel> _liste = [];

  /// Au-delà, le plus ancien s'efface : la recherche reste rapide.
  static const int maximum = 400;

  /// Assez proche d'un exemple pour en prendre la classe…
  static const double seuil = 0.5;

  /// … et plus loin d'autant des exemples d'une autre classe.
  static const double ecart = 0.25;

  List<ExemplePersonnel> get liste => List.unmodifiable(_liste);

  Future<void> charger() async {
    final f = fichier;
    if (f == null || !f.existsSync()) return;
    try {
      final json = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      _liste
        ..clear()
        ..addAll([
          for (final e in json['exemples'] as List<dynamic>)
            ExemplePersonnel.depuisJson(e as Map<String, dynamic>),
        ]);
      notifyListeners();
    } on FormatException {
      // Un fichier abîmé ne doit pas empêcher d'écrire.
    }
  }

  Future<void> _enregistrer() async {
    final f = fichier;
    if (f == null) return;
    await f.parent.create(recursive: true);
    final provisoire = File('${f.path}.tmp');
    await provisoire.writeAsString(
      jsonEncode({
        'format': 1,
        'exemples': [for (final e in _liste) e.versJson()],
      }),
    );
    await provisoire.rename(f.path);
  }

  /// [signe] est un [classe] : retenu, et enregistré.
  Future<void> ajouter(List<Trait> signe, String classe) async {
    final cle = cleDuSigne(signe);
    _liste
      ..removeWhere((e) => e.cle == cle)
      ..add(
        ExemplePersonnel(
          classe: classe,
          cle: cle,
          quand: DateTime.now(),
          auStylet: signe.every((t) => t.auStylet),
          traits: [for (final t in signe) List.of(t.points)],
        ),
      );
    if (_liste.length > maximum) _liste.removeAt(0);
    notifyListeners();
    await _enregistrer();
  }

  Future<void> toutEffacer() async {
    _liste.clear();
    notifyListeners();
    await _enregistrer();
  }

  /// La classe corrigée de ces traits-là, s'ils l'ont été.
  String? corrige(List<Trait> signe) {
    if (_liste.isEmpty) return null;
    final cle = cleDuSigne(signe);
    for (final e in _liste.reversed) {
      if (e.cle == cle) return e.classe;
    }
    return null;
  }

  /// Les classes des exemples, de la plus proche à la plus loin, avec la
  /// distance du plus proche exemple de chacune.
  List<(String, double)> voisins(List<Trait> signe) {
    if (_liste.isEmpty) return const [];
    final dessin = dessinDe(signe);
    final parClasse = <String, double>{};
    for (final e in _liste) {
      final d = distanceDessins(dessin, e.dessin);
      parClasse[e.classe] = math.min(parClasse[e.classe] ?? d, d);
    }
    return parClasse.entries.map((e) => (e.key, e.value)).toList()
      ..sort((a, b) => a.$2.compareTo(b.$2));
  }

  /// La classe d'un exemple tout proche, si aucune autre ne s'en approche.
  String? reconnaitre(List<Trait> signe) {
    final v = voisins(signe);
    if (v.isEmpty || v.first.$2 > seuil) return null;
    if (v.length > 1 && v[1].$2 - v.first.$2 < ecart) return null;
    return v.first.$1;
  }

  /// Les exemples au format de `collecte/FORMAT.md`, pour qu'Antsa puisse
  /// les verser à l'entraînement. Les classes inconnues de
  /// `collecte/classes.txt` sont laissées de côté.
  String exporter({
    required String modele,
    required Size ecranDp,
    required double densite,
    DateTime? maintenant,
  }) {
    final debut = _liste.isEmpty
        ? (maintenant ?? DateTime.now())
        : _liste.map((e) => e.quand).reduce((a, b) => a.isBefore(b) ? a : b);
    final auStylet = _liste.every((e) => e.auStylet);
    return const JsonEncoder.withIndent(' ').convert({
      'format': 1,
      'licence': 'CC0-1.0',
      'auteur': '',
      'appareil': {
        'modele': modele,
        'largeur_dp': ecranDp.width.round(),
        'hauteur_dp': ecranDp.height.round(),
        'densite': densite,
      },
      'outil': auStylet ? 'stylet' : 'doigt',
      'debut': _iso(debut),
      'echantillons': [
        for (final e in _liste)
          if (idDeClasse(e.classe) case final id?) _echantillon(e, id),
      ],
    });
  }

  static Map<String, dynamic> _echantillon(ExemplePersonnel e, String id) {
    final t0 = e.traits.first.first.tempsMs ?? 0;
    final points = [for (final t in e.traits) ...t];
    final (g, h) = (
      points.map((p) => p.x).reduce(math.min),
      points.map((p) => p.y).reduce(math.min),
    );
    final (d, b) = (
      points.map((p) => p.x).reduce(math.max),
      points.map((p) => p.y).reduce(math.max),
    );
    final cadre = Rect.fromLTRB(g, h, d, b);
    double arrondi(double v) => (v * 100).roundToDouble() / 100;
    return {
      'id':
          e.cle.hashCode.toUnsigned(32).toRadixString(16) +
          e.quand.microsecondsSinceEpoch.toRadixString(16),
      'type': 'signe',
      'classe': id,
      'attendu': e.classe,
      'traits': [
        for (final t in e.traits)
          [
            for (final p in t)
              [
                arrondi(p.x),
                arrondi(p.y),
                ((p.tempsMs ?? t0) - t0).roundToDouble(),
                arrondi(p.pression),
              ],
          ],
      ],
      'case': [
        arrondi(cadre.left),
        arrondi(cadre.top),
        arrondi(cadre.width),
        arrondi(cadre.height),
      ],
      'rejete': false,
    };
  }

  /// `2026-11-08T09:30:00+03:00` : l'heure locale et son décalage.
  static String _iso(DateTime d) {
    final local = d.toLocal();
    final o = local.timeZoneOffset;
    String deux(int n) => n.abs().toString().padLeft(2, '0');
    final signe = o.isNegative ? '-' : '+';
    final base = local.toIso8601String().split('.').first;
    return '$base$signe${deux(o.inHours)}:${deux(o.inMinutes % 60)}';
  }
}
