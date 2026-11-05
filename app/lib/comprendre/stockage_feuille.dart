import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Sauvegarde de la feuille : JSON lisible, sur l'appareil seulement.
///
/// Écriture dans un fichier voisin puis renommage : une coupure ne casse pas la
/// feuille. Un fichier illisible est mis de côté, jamais écrasé.
class StockageFeuille {
  new(this.fichier);

  static const int format = 1;

  final File fichier;
  Timer? _minuteur;
  Map<String, dynamic> Function()? _source;

  Map<String, dynamic>? charger() {
    if (!fichier.existsSync()) return null;
    try {
      final json = jsonDecode(fichier.readAsStringSync());
      final document = json as Map<String, dynamic>;
      if (document['format'] != format) throw const FormatException('format');
      return document;
    } on Object {
      fichier.renameSync('${fichier.path}.illisible');
      return null;
    }
  }

  /// Enregistre peu après le dernier changement.
  void programmer(Map<String, dynamic> Function() source) {
    _source = source;
    _minuteur?.cancel();
    _minuteur = Timer(const Duration(seconds: 1), enregistrer);
  }

  void enregistrer() {
    _minuteur?.cancel();
    final source = _source;
    if (source == null) return;
    _source = null;
    fichier.parent.createSync(recursive: true);
    File('${fichier.path}.tmp')
      ..writeAsStringSync(
        jsonEncode({'format': format, ...source()}),
        flush: true,
      )
      ..renameSync(fichier.path);
  }
}
