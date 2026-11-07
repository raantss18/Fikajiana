import 'package:flutter/foundation.dart';

/// Les lignes que le Guide demande de poser sur la Feuille (ADR 0036).
///
/// Le Guide revient à la Feuille, qui écoute et prend la demande : elle pose
/// les lignes comme une saisie au clavier, sans dupliquer ce calcul.
class EssaiGuide extends ChangeNotifier {
  List<String>? _lignes;

  /// Une demande attend : la Feuille n'était peut-être pas encore là.
  bool get enAttente => _lignes != null;

  /// Demande de poser [lignes], en LaTeX, dans cet ordre.
  void demander(List<String> lignes) {
    if (lignes.isEmpty) return;
    _lignes = List.unmodifiable(lignes);
    notifyListeners();
  }

  /// Prend la demande : une seule Feuille la pose, une seule fois.
  List<String>? prendre() {
    final lignes = _lignes;
    _lignes = null;
    return lignes;
  }
}
