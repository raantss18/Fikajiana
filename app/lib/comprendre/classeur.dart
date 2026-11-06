import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Ce qu'on montre d'un document dans l'Historique.
class ApercuDocument {
  const new({required this.id, required this.modifie, required this.contenu});

  final String id;
  final DateTime modifie;

  /// Le fichier décodé.
  final Object? contenu;
}

/// Plusieurs documents d'un même genre, et celui qu'on a sous la main : un
/// fichier par document dans [dossier], sur l'appareil seulement.
class Classeur extends ChangeNotifier {
  new({this.dossier, File? ancien, DateTime Function()? horloge})
    : _horloge = horloge ?? DateTime.now {
    final dossier = this.dossier;
    if (dossier == null) {
      _courant = _nouvelId();
      return;
    }
    dossier.createSync(recursive: true);
    // Avant la 0.4, un seul document par genre.
    if (ancien != null && ancien.existsSync()) {
      final date = ancien.lastModifiedSync().microsecondsSinceEpoch;
      ancien.renameSync('${dossier.path}/$date.json');
    }
    final notee = _note.existsSync() ? _note.readAsStringSync().trim() : null;
    final tous = apercus();
    _courant = notee != null && tous.any((a) => a.id == notee)
        ? notee
        : tous.isNotEmpty
        ? tous.first.id
        : _nouvelId();
    _noter();
  }

  final Directory? dossier;
  final DateTime Function() _horloge;
  late String _courant;
  var _dernierId = 0;

  File get _note => File('${dossier!.path}/courant.txt');

  String get courant => _courant;

  /// Où garder le document courant ; `null` sans dossier.
  File? get fichier =>
      dossier == null ? null : File('${dossier!.path}/$_courant.json');

  String _nouvelId() {
    var id = _horloge().microsecondsSinceEpoch;
    if (id <= _dernierId) id = _dernierId + 1;
    _dernierId = id;
    return '$id';
  }

  void _noter() {
    if (dossier != null) _note.writeAsStringSync(_courant);
  }

  /// Les documents enregistrés, le plus récent d'abord. Un fichier illisible
  /// reste en place, sans figurer dans la liste.
  List<ApercuDocument> apercus() {
    final dossier = this.dossier;
    if (dossier == null) return const [];
    final liste = <ApercuDocument>[];
    for (final fichier in dossier.listSync().whereType<File>()) {
      final nom = fichier.uri.pathSegments.last;
      if (!nom.endsWith('.json')) continue;
      try {
        liste.add(
          ApercuDocument(
            id: nom.substring(0, nom.length - 5),
            modifie: fichier.lastModifiedSync(),
            contenu: jsonDecode(fichier.readAsStringSync()),
          ),
        );
      } on Object {
        continue;
      }
    }
    return liste..sort((a, b) => b.modifie.compareTo(a.modifie));
  }

  /// Un document neuf. Celui en cours n'a encore rien : on y reste.
  void nouveau() {
    final fichier = this.fichier;
    if (fichier != null && !fichier.existsSync()) return;
    _courant = _nouvelId();
    _noter();
    notifyListeners();
  }

  void ouvrir(String id) {
    if (id == _courant) return;
    _courant = id;
    _noter();
    notifyListeners();
  }

  /// Supprime un document ; si c'était le courant, passe au plus récent.
  void supprimer(String id) {
    final dossier = this.dossier;
    if (dossier == null) return;
    final fichier = File('${dossier.path}/$id.json');
    if (fichier.existsSync()) fichier.deleteSync();
    if (id == _courant) {
      final reste = apercus();
      _courant = reste.isNotEmpty ? reste.first.id : _nouvelId();
      _noter();
    }
    notifyListeners();
  }
}
