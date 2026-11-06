import 'package:fikajiana_math/src/lecteur_latex.dart';

/// Ce que l'écriture semble être.
enum TypeExpression {
  /// Une valeur à calculer : `2+3`, `2+3=`, `\sin(\pi)`.
  calcul,

  /// Une équation à résoudre : `x^2=2`.
  equation,

  /// Un système à résoudre : accolade ou matrice de relations.
  systeme,

  /// Une fonction à définir : `f(x)=x^2`.
  fonction,

  /// Une matrice.
  matrice,
}

/// Résultat de l'analyse d'un LaTeX : son type et l'entrée à donner à Giac.
class Analyse {
  /// Crée une analyse.
  const new(this.type, this.giac, {this.inconnues = const []});

  /// Type deviné.
  final TypeExpression type;

  /// Entrée Giac.
  final String giac;

  /// Ce que Giac résout, dans l'ordre de ses solutions.
  final List<String> inconnues;
}

/// Le LaTeX n'a pas pu être compris.
class ErreurLatex implements Exception {
  /// Crée l'erreur.
  const new(this.message);

  /// Détail, pour le débogage.
  final String message;

  @override
  String toString() => 'ErreurLatex: $message';
}

/// Analyse un LaTeX lu ou corrigé, et le traduit pour Giac.
///
/// [degres] : Giac compte en degrés ; `30°` reste donc `30`.
///
/// Lève [ErreurLatex] si le texte n'est pas compris : aucun résultat deviné.
Analyse analyserLatex(String latex, {bool degres = false}) {
  final lecture = LecteurLatex(latex, degres: degres).lire();

  if (lecture is LectureSysteme) {
    final inconnues = <String>{};
    for (final relation in lecture.relations) {
      inconnues.addAll(relation.symboles);
    }
    final variables = _ordonner(inconnues);
    final relations = lecture.relations.map((r) => r.giac).join(',');
    return Analyse(
      TypeExpression.systeme,
      'solve([$relations],[${variables.join(',')}])',
      inconnues: variables,
    );
  }

  final expression = lecture as LectureExpression;
  final droite = expression.droite;
  if (!expression.aEgal) {
    return Analyse(
      expression.gauche.estMatrice
          ? TypeExpression.matrice
          : TypeExpression.calcul,
      expression.gauche.giac,
    );
  }
  if (droite == null) {
    return Analyse(TypeExpression.calcul, expression.gauche.giac);
  }

  final definition = expression.gauche.definitionDeFonction;
  if (definition != null) {
    return Analyse(TypeExpression.fonction, '$definition:=${droite.giac}');
  }
  final symboles = {...expression.gauche.symboles, ...droite.symboles};
  if (symboles.isEmpty) {
    return Analyse(
      TypeExpression.calcul,
      'normal((${expression.gauche.giac})-(${droite.giac}))==0',
    );
  }
  final variable = _ordonner(symboles).first;
  return Analyse(
    TypeExpression.equation,
    'solve(${expression.gauche.giac}=${droite.giac},$variable)',
    inconnues: [variable],
  );
}

/// Inconnues usuelles d'abord : x, y, z, t, puis l'ordre alphabétique.
List<String> _ordonner(Set<String> symboles) {
  const usuelles = ['x', 'y', 'z', 't'];
  return [
    ...usuelles.where(symboles.contains),
    ...symboles.where((s) => !usuelles.contains(s)).toList()..sort(),
  ];
}
