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
  });

  final String id;
  final DateTime modifiee;
  final int traits;

  /// Ce qui a été lu ou saisi, en LaTeX.
  final List<String> calculs;

  bool get estVide => traits == 0 && calculs.isEmpty;
}

/// Toutes les feuilles, et celle qu'on a sous la main.
///
/// Chaque feuille est un fichier de `feuilles/`, sur l'appareil seulement.
class Carnet extends ChangeNotifier {
  new({this.dossier, DateTime Function()? horloge})
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

  /// Les feuilles enregistrées, la plus récente d'abord. Un fichier illisible
  /// reste en place, sans figurer dans la liste.
  List<ApercuFeuille> apercus() {
    if (dossier == null) return const [];
    final liste = <ApercuFeuille>[];
    for (final fichier in _feuilles.listSync().whereType<File>()) {
      final nom = fichier.uri.pathSegments.last;
      if (!nom.endsWith('.json')) continue;
      try {
        final json =
            jsonDecode(fichier.readAsStringSync()) as Map<String, dynamic>;
        liste.add(
          ApercuFeuille(
            id: nom.substring(0, nom.length - 5),
            modifiee: fichier.lastModifiedSync(),
            traits: (json['traits'] as List<dynamic>? ?? const []).length,
            calculs: [
              for (final bloc
                  in (json['blocs'] as List<dynamic>? ?? const [])
                      .cast<Map<String, dynamic>>())
                if (bloc['latex'] case final String latex) latex,
            ],
          ),
        );
      } on Object {
        continue;
      }
    }
    return liste..sort((a, b) => b.modifiee.compareTo(a.modifiee));
  }

  /// Une feuille neuve. Celle en cours est déjà vide : on y reste.
  void nouvelle() {
    if (dossier != null &&
        !File('${_feuilles.path}/$_courante.json').existsSync()) {
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

  /// Supprime une feuille ; si c'était la courante, passe à la plus récente.
  void supprimer(String id) {
    if (dossier == null) return;
    final fichier = File('${_feuilles.path}/$id.json');
    if (fichier.existsSync()) fichier.deleteSync();
    if (id == _courante) {
      final reste = apercus();
      _courante = reste.isNotEmpty ? reste.first.id : _nouvelId();
      _noter();
    }
    notifyListeners();
  }
}
