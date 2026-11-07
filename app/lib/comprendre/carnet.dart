import 'dart:convert';
import 'dart:io';

import 'package:fikajiana/comprendre/stockage_feuille.dart';
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

/// Avant la 0.10, la Figure en cours n'appartenait à aucune feuille : on
/// la rattache à la feuille en cours, une seule fois. Les autres figures et
/// graphes deviennent des documents à part : rien ne se perd (ADR 0032).
void rattacherFiguresAuxFeuilles(Directory dossier, List<String> annexes) {
  final marque = File('${dossier.path}/documents.txt');
  if (marque.existsSync()) return;
  final note = File('${dossier.path}/courante.txt');
  final feuille = note.existsSync() ? note.readAsStringSync().trim() : null;
  if (feuille != null && feuille.isNotEmpty) {
    for (final annexe in annexes) {
      final noteAnnexe = File('${dossier.path}/$annexe/courant.txt');
      if (!noteAnnexe.existsSync()) continue;
      final courant = noteAnnexe.readAsStringSync().trim();
      final source = File('${dossier.path}/$annexe/$courant.json');
      final cible = File('${dossier.path}/$annexe/$feuille.json');
      if (courant != feuille && source.existsSync() && !cible.existsSync()) {
        source.renameSync(cible.path);
      }
    }
  }
  marque.writeAsStringSync('1');
}
