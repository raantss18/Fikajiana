import 'dart:convert';
import 'dart:io';

import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter/foundation.dart';

/// Une fonction à tracer : ce qui a été écrit, et sa traduction pour le calcul.
class Courbe {
  const new({required this.latex, required this.corps, required this.variable});

  final String latex;
  final String corps;
  final String variable;

  FonctionReelle fonction({required bool degres}) =>
      compilerFonction(corps, variable: variable, degres: degres);
}

/// Traduit `f(x)=x^2`, `y=2x+1` ou `x^2` ; `null` si ce n'est pas traçable.
Courbe? lireCourbe(String latex) {
  final Analyse analyse;
  try {
    analyse = analyserLatex(latex);
  } on ErreurLatex {
    return null;
  }
  final fonction = analyse.type == TypeExpression.fonction;
  if (!fonction && analyse.type != TypeExpression.calcul) return null;
  final courbe = Courbe(
    latex: latex,
    corps: fonction ? analyse.corps! : analyse.giac,
    variable: fonction ? analyse.inconnues.single : 'x',
  );
  try {
    courbe.fonction(degres: false);
  } on ErreurEvaluation {
    return null;
  }
  return courbe;
}

/// Les fonctions tracées, gardées sur l'appareil.
class Courbes extends ChangeNotifier {
  new({this.fichier}) {
    final fichier = this.fichier;
    if (fichier == null || !fichier.existsSync()) return;
    try {
      final liste = jsonDecode(fichier.readAsStringSync()) as List<dynamic>;
      _courbes.addAll(liste.cast<String>().map(lireCourbe).nonNulls);
    } on Object {
      // Un fichier abîmé est mis de côté, jamais écrasé.
      fichier.renameSync('${fichier.path}.illisible');
    }
  }

  static const int maximum = 6;

  final File? fichier;
  final _courbes = <Courbe>[];

  List<Courbe> get liste => List.unmodifiable(_courbes);

  /// Ajoute [latex] ; `false` s'il n'est pas traçable. Déjà là : rien à faire.
  bool ajouter(String latex) {
    final courbe = lireCourbe(latex);
    if (courbe == null) return false;
    if (_courbes.any((c) => c.corps == courbe.corps)) return true;
    if (_courbes.length == maximum) _courbes.removeAt(0);
    _courbes.add(courbe);
    _changer();
    return true;
  }

  /// Remplace la courbe [indice] ; `false` si [latex] n'est pas traçable.
  bool remplacer(int indice, String latex) {
    final courbe = lireCourbe(latex);
    if (courbe == null) return false;
    _courbes[indice] = courbe;
    _changer();
    return true;
  }

  void retirer(int indice) {
    _courbes.removeAt(indice);
    _changer();
  }

  void _changer() {
    notifyListeners();
    fichier?.writeAsStringSync(jsonEncode([for (final c in _courbes) c.latex]));
  }
}
