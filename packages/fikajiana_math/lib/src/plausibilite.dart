import 'package:fikajiana_math/src/analyse.dart';
import 'package:fikajiana_math/src/objets.dart';
import 'package:fikajiana_math/src/redressement.dart';

/// Lettres qu'on rencontre tout le temps : les autres sont souvent mal lues.
const _lettresUsuelles = 'abcdefghknrstuvxyz';

/// À quel point une lecture a du sens en maths : 0 si rien n'étonne, négatif
/// sinon. Le contexte de la feuille compte : une fonction connue rassure.
///
/// Ce score départage des lectures ; il ne dit pas qu'une lecture est juste.
int plausibilite(String latex, {Set<String> fonctions = const {}}) {
  final redresse = redresserLecture(latex, fonctions: fonctions)
      // Un nom de vecteur ou de point n'étonne pas.
      .replaceAll(RegExp(r'\\(?:overrightarrow|vec)\s*\{[^{}]*\}'), r'\pi');
  var score = 0;
  // Deux lignes lues comme une matrice : un `=` dans une cellule.
  final matrice = RegExp(
    r'\\begin\{(?:matrix|array|pmatrix|bmatrix)\}(.*?)\\end\{',
    dotAll: true,
  ).firstMatch(redresse);
  if (matrice != null && matrice[1]!.contains('=')) score -= 50;

  if (lireObjet(redresse) != null) return score;
  final Analyse analyse;
  try {
    analyse = analyserLatex(
      redresse,
      definitions: {
        for (final nom in fonctions)
          nom: const DefinitionFonction(variable: 'x', corps: 'x'),
      },
    );
  } on ErreurLatex {
    return score - 100;
  }

  // Un `=` qui reste seul dans un calcul se comprend ; une équation sans
  // lettre usuelle, moins.
  final lettres = RegExp(r'(?<![\\a-zA-Z])[a-zA-Z](?![a-zA-Z])')
      .allMatches(redresse.replaceAll(RegExp(r'\\[a-zA-Z]+'), ' '));
  for (final m in lettres) {
    final l = m[0]!;
    if (!_lettresUsuelles.contains(l) && !fonctions.contains(l)) score -= 2;
  }
  // Une longue suite de lettres collées : un mot, pas un produit.
  final texte = redresse
      .replaceAll(RegExp(r'\\[a-zA-Z]+'), ' ')
      .replaceAll(' ', '');
  if (RegExp('[a-zA-Z]{4,}').hasMatch(texte)) score -= 10;
  // Un chiffre juste après une lettre, sans exposant : `x2` s'écrit rarement.
  if (RegExp('[a-zA-Z][0-9]').hasMatch(texte)) score -= 2;
  // Une équation dont les deux membres sont sans lettre, et fausse à l'œil,
  // n'est pas jugée ici : c'est le calcul qui répond.
  if (analyse.type == TypeExpression.matrice && !latex.contains('begin')) {
    score -= 5;
  }
  return score;
}

/// La lecture à garder parmi [lectures], rangées par le modèle : la plus
/// plausible, et à égalité celle que le modèle préfère. La première ne cède
/// que devant un écart net.
String choisirLecture(
  List<String> lectures, {
  Set<String> fonctions = const {},
}) {
  var meilleure = lectures.first;
  var score = plausibilite(meilleure, fonctions: fonctions);
  for (final autre in lectures.skip(1)) {
    final s = plausibilite(autre, fonctions: fonctions);
    if (s >= score + 2) (meilleure, score) = (autre, s);
  }
  return meilleure;
}
