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
  const new(
    this.type,
    this.giac, {
    this.inconnues = const [],
    this.corps,
    this.membres,
    this.nomFonction,
    this.demandeResultat = false,
  });

  /// Type deviné.
  final TypeExpression type;

  /// Entrée Giac.
  final String giac;

  /// Le corps d'une fonction, `x^2` pour `f(x)=x^2`, à évaluer ou à tracer.
  final String? corps;

  /// Ce que Giac résout, dans l'ordre de ses solutions ; la variable d'une
  /// fonction.
  final List<String> inconnues;

  /// Les deux membres d'une équation, traduits pour Giac.
  final (String, String)? membres;

  /// `f` pour `f(x)=x^2`, à retenir pour les lignes suivantes.
  final String? nomFonction;

  /// La réponse s'affiche même sans `=` : `f'(x)`, `det(…)`.
  final bool demandeResultat;

  /// Pour les lignes suivantes, si c'est une définition.
  DefinitionFonction? get definition => nomFonction == null
      ? null
      : DefinitionFonction(variable: inconnues.single, corps: corps!);
}

/// Une fonction définie plus haut sur la feuille : `f(x)=x+5`.
class DefinitionFonction {
  /// Crée la définition.
  const new({
    required this.variable,
    required this.corps,
    this.symboles = const {},
  });

  /// Sa variable, `x`.
  final String variable;

  /// Son corps, traduit pour Giac.
  final String corps;

  /// Les lettres de son corps.
  final Set<String> symboles;

  /// `f(2)`, ou `f'(2)` pour [primes] à 1, traduit pour Giac.
  String appel(String argument, {int primes = 0}) {
    if (primes == 0) {
      if (argument == variable) return '($corps)';
      return '(${corps.replaceAll(RegExp('\\b$variable\\b'), '($argument)')})';
    }
    final derivee = primes == 1
        ? 'diff($corps,$variable)'
        : 'diff($corps,$variable,$primes)';
    return argument == variable
        ? derivee
        : 'subst($derivee,$variable=$argument)';
  }
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
///
/// [definitions] : les fonctions écrites plus haut sur la feuille. `f'(x)` est
/// alors sa dérivée, et `f(x)=0` une équation.
Analyse analyserLatex(
  String latex, {
  bool degres = false,
  Map<String, DefinitionFonction> definitions = const {},
}) {
  final lecteur = LecteurLatex(latex, degres: degres, definitions: definitions);
  final lecture = lecteur.lire();
  final demande = lecteur.demandeResultat;

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
      demandeResultat: demande,
    );
  }
  if (droite == null) {
    return Analyse(
      TypeExpression.calcul,
      expression.gauche.giac,
      demandeResultat: demande,
    );
  }

  final definition = expression.gauche.definitionDeFonction;
  // `f` est déjà définie : `f(x)=0` est une équation, `f(x)=2x` la redéfinit.
  final estEquation =
      expression.gauche.fonctionDefinie && droite.symboles.isEmpty;
  if (definition != null && !estEquation) {
    final variable = definition.substring(
      definition.indexOf('(') + 1,
      definition.length - 1,
    );
    return Analyse(
      TypeExpression.fonction,
      '$definition:=${droite.giac}',
      inconnues: [variable],
      corps: droite.giac,
      nomFonction: definition.substring(0, definition.indexOf('(')),
    );
  }
  // `y=2x+1` : une courbe à tracer, pas une équation d'inconnue x.
  if (expression.gauche.giac == 'y' &&
      droite.symboles.length == 1 &&
      !droite.symboles.contains('y')) {
    final variable = droite.symboles.single;
    return Analyse(
      TypeExpression.fonction,
      'y($variable):=${droite.giac}',
      inconnues: [variable],
      corps: droite.giac,
      nomFonction: 'y',
    );
  }
  final symboles = {...expression.gauche.symboles, ...droite.symboles};
  final ordre = expression.ordre;
  if (ordre != null) {
    final relation = '${expression.gauche.giac}$ordre${droite.giac}';
    if (symboles.isEmpty) return Analyse(TypeExpression.calcul, relation);
    final variable = _ordonner(symboles).first;
    return Analyse(
      TypeExpression.equation,
      'solve($relation,$variable)',
      inconnues: [variable],
    );
  }
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
    membres: (expression.gauche.giac, droite.giac),
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
