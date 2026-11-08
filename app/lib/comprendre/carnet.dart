import 'dart:convert';
import 'dart:io';

import 'package:fikajiana/comprendre/stockage_feuille.dart';
import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter/foundation.dart';

/// Ce qu'on montre d'une feuille dans l'Historique.
class ApercuFeuille {
  const new({
    required this.id,
    required this.modifiee,
    required this.traits,
    required this.calculs,
    this.courbes = const [],
    this.objets = 0,
  });

  final String id;
  final DateTime modifiee;
  final int traits;

  /// Ce qui a été lu ou saisi, en LaTeX.
  final List<String> calculs;

  /// Les courbes de sa Figure, en LaTeX.
  final List<String> courbes;

  /// Les objets de géométrie de sa Figure.
  final int objets;

  bool get estVide =>
      traits == 0 && calculs.isEmpty && courbes.isEmpty && objets == 0;
}

/// Tous les documents, et celui qu'on a sous la main.
///
/// Un document, c'est une feuille et sa Figure, sous un même nom :
/// `feuilles/<id>.json`, et dans chaque dossier d'[annexes] (`graphes/`,
/// `figures/`) le fichier `<id>.json`. Sur l'appareil seulement (ADR 0032).
class Carnet extends ChangeNotifier {
  new({this.dossier, DateTime Function()? horloge, this.annexes = const []})
    : _horloge = horloge ?? DateTime.now {
    final dossier = this.dossier;
    if (dossier == null) {
      _courante = _nouvelId();
      return;
    }
    _feuilles.createSync(recursive: true);
    // La 0.2.0 et avant n'avaient qu'une feuille.
    final ancienne = File('${dossier.path}/feuille.json');
    if (ancienne.existsSync()) {
      final date = ancienne.lastModifiedSync().microsecondsSinceEpoch;
      ancienne.renameSync('${_feuilles.path}/$date.json');
    }
    final notee = _noteCourante.existsSync()
        ? _noteCourante.readAsStringSync().trim()
        : null;
    final toutes = apercus();
    _courante = notee != null && toutes.any((a) => a.id == notee)
        ? notee
        : toutes.isNotEmpty
        ? toutes.first.id
        : _nouvelId();
    _noter();
  }

  final Directory? dossier;

  /// Les dossiers, sous [dossier], qui gardent la Figure de chaque document.
  final List<String> annexes;
  final DateTime Function() _horloge;
  late String _courante;
  var _dernierId = 0;

  Directory get _feuilles => Directory('${dossier!.path}/feuilles');
  File get _noteCourante => File('${dossier!.path}/courante.txt');

  String get courante => _courante;

  /// Où garder la feuille courante ; `null` sans dossier.
  StockageFeuille? get stockage => dossier == null
      ? null
      : StockageFeuille(File('${_feuilles.path}/$_courante.json'));

  String _nouvelId() {
    var id = _horloge().microsecondsSinceEpoch;
    // Deux feuilles créées au même instant restent distinctes.
    if (id <= _dernierId) id = _dernierId + 1;
    _dernierId = id;
    return '$id';
  }

  void _noter() {
    if (dossier != null) _noteCourante.writeAsStringSync(_courante);
  }

  List<Directory> get _dossiers => [
    _feuilles,
    for (final a in annexes) Directory('${dossier!.path}/$a'),
  ];

  /// Les fichiers du document [id] : sa feuille, puis sa Figure.
  List<File> _fichiers(String id) => [
    for (final d in _dossiers) File('${d.path}/$id.json'),
  ];

  /// Les documents enregistrés, le plus récent d'abord. Un document dont
  /// seule la Figure existe en est un aussi. Un fichier illisible reste en
  /// place, sans figurer dans la liste.
  List<ApercuFeuille> apercus() {
    if (dossier == null) return const [];
    final ids = <String>{
      for (final d in _dossiers)
        if (d.existsSync())
          for (final f in d.listSync().whereType<File>())
            if (f.path.endsWith('.json'))
              f.uri.pathSegments.last.replaceAll('.json', ''),
    };
    final liste = <ApercuFeuille>[];
    for (final id in ids) {
      try {
        final fichiers = _fichiers(id).where((f) => f.existsSync()).toList();
        final modifiee = fichiers
            .map((f) => f.lastModifiedSync())
            .reduce((a, b) => a.isAfter(b) ? a : b);
        final feuille = File('${_feuilles.path}/$id.json');
        final json = feuille.existsSync()
            ? jsonDecode(feuille.readAsStringSync()) as Map<String, dynamic>
            : const <String, dynamic>{};
        final courbes = <String>[];
        var objets = 0;
        for (final a in annexes) {
          final f = File('${dossier!.path}/$a/$id.json');
          if (!f.existsSync()) continue;
          switch (jsonDecode(f.readAsStringSync())) {
            case final List<dynamic> liste:
              courbes.addAll(liste.whereType<String>());
            case final Map<String, dynamic> carte:
              objets += (carte['objets'] as List<dynamic>? ?? const []).length;
          }
        }
        liste.add(
          ApercuFeuille(
            id: id,
            modifiee: modifiee,
            traits: (json['traits'] as List<dynamic>? ?? const []).length,
            calculs: [
              for (final bloc
                  in (json['blocs'] as List<dynamic>? ?? const [])
                      .cast<Map<String, dynamic>>())
                if (bloc['latex'] case final String latex) latex,
            ],
            courbes: courbes,
            objets: objets,
          ),
        );
      } on Object {
        continue;
      }
    }
    return liste..sort((a, b) => b.modifiee.compareTo(a.modifiee));
  }

  /// Un document neuf, feuille et Figure vides. Celui en cours n'a encore
  /// rien : on y reste.
  void nouvelle() {
    if (dossier != null && !_fichiers(_courante).any((f) => f.existsSync())) {
      return;
    }
    _courante = _nouvelId();
    _noter();
    notifyListeners();
  }

  void ouvrir(String id) {
    if (id == _courante) return;
    _courante = id;
    _noter();
    notifyListeners();
  }

  /// Supprime un document, feuille et Figure ; si c'était le courant, passe
  /// au plus récent.
  void supprimer(String id) {
    if (dossier == null) return;
    for (final fichier in _fichiers(id)) {
      if (fichier.existsSync()) fichier.deleteSync();
    }
    if (id == _courante) {
      final reste = apercus();
      _courante = reste.isNotEmpty ? reste.first.id : _nouvelId();
      _noter();
    }
    notifyListeners();
  }
}

/// Avant la 1.0, une Figure n'appartenait à aucune feuille : chacune est
/// rattachée à la feuille dont elle reprend le contenu (ses points, ses
/// courbes). Sans feuille qui lui ressemble, elle reste un document à part :
/// rien ne se perd (ADR 0032). La 0.10 de développement l'attachait à la
/// feuille en cours : la marque 2 refait ce choix.
void rattacherFiguresAuxFeuilles(Directory dossier, List<String> annexes) {
  final marque = File('${dossier.path}/documents.txt');
  if (marque.existsSync() && marque.readAsStringSync().trim() == '2') return;
  final feuilles = <String, Set<String>>{};
  final dossierFeuilles = Directory('${dossier.path}/feuilles');
  if (dossierFeuilles.existsSync()) {
    for (final f in dossierFeuilles.listSync().whereType<File>()) {
      if (!f.path.endsWith('.json')) continue;
      try {
        final json = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
        feuilles[f.uri.pathSegments.last.replaceAll('.json', '')] = {
          for (final b
              in (json['blocs'] as List<dynamic>? ?? const [])
                  .cast<Map<String, dynamic>>())
            if (b['latex'] case final String latex) _empreinte(latex),
        };
      } on Object {
        continue;
      }
    }
  }
  for (final annexe in annexes) {
    final d = Directory('${dossier.path}/$annexe');
    if (!d.existsSync()) continue;
    for (final f in d.listSync().whereType<File>().toList()) {
      if (!f.path.endsWith('.json')) continue;
      final id = f.uri.pathSegments.last.replaceAll('.json', '');
      final Set<String> traces;
      try {
        traces = _tracesDeLaFigure(jsonDecode(f.readAsStringSync()));
      } on Object {
        continue;
      }
      int score(String feuille) =>
          traces.where((t) => feuilles[feuille]!.contains(t)).length;
      final meilleure = feuilles.keys.fold<String?>(
        null,
        (m, k) => score(k) > (m == null ? 0 : score(m)) ? k : m,
      );
      if (meilleure == null || meilleure == id) continue;
      if (feuilles.containsKey(id) && score(id) >= score(meilleure)) continue;
      final cible = File('${d.path}/$meilleure.json');
      if (!cible.existsSync()) f.renameSync(cible.path);
    }
  }
  marque.writeAsStringSync('2');
}

/// Ce qu'une Figure a dû recevoir d'une feuille : ses courbes, ses points.
Set<String> _tracesDeLaFigure(Object? contenu) => switch (contenu) {
  final List<dynamic> courbes => {
    for (final c in courbes.whereType<String>()) _empreinte(c),
  },
  final Map<String, dynamic> figure => {
    for (final o
        in (figure['objets'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>())
      if (o case {'t': 'libre', 'a': {'n': final String nom}})
        _empreinte('$nom(${_nombre(o['x'])};${_nombre(o['y'])})'),
  },
  _ => const {},
};

String _nombre(Object? v) {
  final d = (v as num?)?.toDouble() ?? 0;
  return d == d.roundToDouble() ? '${d.round()}' : '$d';
}

/// Une écriture sans ses espaces ni ses habits : `A ( 1 ; 2 )` vaut `A(1;2)`,
/// et `B(5,-4)` aussi bien que `B(5;-4)`.
String _empreinte(String latex) => sansLeftRight(latex)
    .replaceAll(RegExp(r'\s'), '')
    .replaceAll(',', ';');
