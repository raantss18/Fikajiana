/// Le supérieur (vague 7 de `docs/recherche/couverture-calcul.md`, ADR 0059) :
///
/// - `DL(f;a;n)`, `taylor(f;a;n)` : développement limité à l'ordre n en a
///   (Giac `taylor`) ;
/// - `laplace(f)`, `invlaplace(F)` : transformée de Laplace et son inverse
///   (Giac `laplace`, `invlaplace`) ;
/// - `rang(A)`, `tr(A)`, `noyau(A)`, `valeurspropres(A)`, `vecteurspropres(A)`,
///   `polycar(A)`, `diagonaliser(A)` (Giac `rank`, `trace`, `ker`,
///   `eigenvals`, `eigenvects`, `charpoly`, `jordan`).
///
/// Doc Giac : <https://www-fourier.univ-grenoble-alpes.fr/~parisse/giac/doc/fr/cascmd_fr/cascmd_fr471.html>
/// (`taylor`), cascmd_fr703.html (`laplace`), cascmd_fr617.html (`rank`),
/// cascmd_fr623.html (`ker`), cascmd_fr642.html (`eigenvals`),
/// cascmd_fr646.html (`jordan`).
library;

import 'package:fikajiana_math/src/lecteur_latex.dart' show normaliserNom;

/// Ce qu'une ligne du supérieur demande.
enum Superieur {
  /// Développement limité.
  taylor,

  /// Transformée de Laplace.
  laplace,

  /// Transformée de Laplace inverse.
  invlaplace,

  /// Rang d'une matrice.
  rang,

  /// Trace (`tr` : `trace` veut déjà dire « tracer » en anglais).
  trace,

  /// Noyau.
  noyau,

  /// Valeurs propres.
  valeursPropres,

  /// Vecteurs propres, en colonnes.
  vecteursPropres,

  /// Polynôme caractéristique det(xI − A).
  polynomeCaracteristique,

  /// P et D (ou J si la matrice n'est pas diagonalisable).
  diagonaliser,
}

/// Noms (sans accent ni tiret) de chaque commande, en français et en anglais.
const Map<String, Superieur> nomsDuSuperieur = {
  'taylor': Superieur.taylor,
  'dl': Superieur.taylor,
  'developpementlimite': Superieur.taylor,
  'laplace': Superieur.laplace,
  'invlaplace': Superieur.invlaplace,
  'laplaceinverse': Superieur.invlaplace,
  'rang': Superieur.rang,
  'rank': Superieur.rang,
  'tr': Superieur.trace,
  'noyau': Superieur.noyau,
  'ker': Superieur.noyau,
  'valeurspropres': Superieur.valeursPropres,
  'eigenvals': Superieur.valeursPropres,
  'spectre': Superieur.valeursPropres,
  'vecteurspropres': Superieur.vecteursPropres,
  'eigenvects': Superieur.vecteursPropres,
  'polycar': Superieur.polynomeCaracteristique,
  'charpoly': Superieur.polynomeCaracteristique,
  'polynomecaracteristique': Superieur.polynomeCaracteristique,
  'diagonaliser': Superieur.diagonaliser,
  'diagonalize': Superieur.diagonaliser,
  'jordan': Superieur.diagonaliser,
};

/// Les commandes à deux ou trois arguments séparés par `;` au clavier.
const nomsDuSuperieurAPlusieursArguments = {
  'taylor',
  'dl',
  'developpementlimite',
};

/// Ce que Giac calcule pour une commande sur une matrice [m].
String giacMatrice(Superieur commande, String m) => switch (commande) {
  Superieur.rang => 'rank($m)',
  Superieur.trace => 'trace($m)',
  Superieur.noyau => 'ker($m)',
  // Giac rend une suite `3,1` : entre crochets, elle s'écrit et se relit.
  Superieur.valeursPropres => '[eigenvals($m)]',
  Superieur.vecteursPropres => 'eigenvects($m)',
  Superieur.polynomeCaracteristique => 'charpoly($m,x)',
  // `jordan` rend P et J ; J est diagonale si et seulement si A est
  // diagonalisable.
  Superieur.diagonaliser =>
    '[[jordan($m)],[jordan($m)][1]==diag(diag([jordan($m)][1]))]',
  _ => throw ArgumentError('$commande ne porte pas sur une matrice'),
};

/// La commande du supérieur que demande [ligne], ou `null`. Sur une matrice,
/// la parenthèse peut manquer, comme pour `\det` : `rang\begin{pmatrix}…`.
Superieur? superieurDemande(String ligne) {
  final nom = RegExp(
    r'^\s*\\?(?:(?:operatorname|mathrm|text|textrm)\s*\{\s*)?([A-Za-zéèêàùûôîç\s_-]+?)\s*\}?\s*(?:(?:\\left)?\s*\(|\\begin\b)',
  ).firstMatch(ligne);
  if (nom == null) return null;
  return nomsDuSuperieur[normaliserNom(nom[1]!)];
}

/// Écrit la réponse de Giac à [commande] comme au tableau, ou `null` si elle
/// s'affiche telle quelle ou n'a pas la forme attendue.
String? ecrireSuperieur(
  Superieur commande,
  String reponse, {
  required bool francais,
}) => switch (commande) {
  Superieur.taylor => _petitO(reponse),
  Superieur.noyau => _noyau(reponse),
  Superieur.valeursPropres => _spectre(reponse),
  Superieur.diagonaliser => _diagonale(reponse, francais: francais),
  _ => null,
};

/// `… + x^{5}\mathrm{order\_size}(x)` : Giac écrit le reste x⁵·ε(x), qui est
/// un o(x⁴) ; on l'écrit comme au tableau, `+o(x^{4})`.
String? _petitO(String latex) {
  final reste = RegExp(
    r'([+-])?\s*((?:\\left\((?:[^()]|\([^()]*\))*\\right\))|[a-zA-Z])'
    r'(?:\^\{(\d+)\})?\s*(?:\\cdot\s*)?\\mathrm\{order\\_size\}\\left\((?:[^()]|\([^()]*\))*\\right\)\s*$',
  ).firstMatch(latex);
  if (reste == null) return null;
  final puissance = int.parse(reste[3] ?? '1') - 1;
  final base = reste[2]!;
  final o = switch (puissance) {
    0 => r'o\left(1\right)',
    1 => 'o\\left($base\\right)',
    _ => 'o\\left($base^{$puissance}\\right)',
  };
  final debut = latex.substring(0, reste.start).trimRight();
  return debut.isEmpty ? o : '$debut+$o';
}

/// `[]` : {0} ; sinon une base, chaque vecteur en colonne.
String? _noyau(String latex) {
  final t = latex.trim();
  if (t == '[]') return r'\{0\}';
  final lignes = _lignesDeTableau(t);
  if (lignes == null || lignes.isEmpty) return null;
  final vecteurs = [
    for (final l in lignes) '\\begin{pmatrix}${l.join(r'\\')}\\end{pmatrix}',
  ];
  return '\\mathrm{Vect}\\left(${vecteurs.join(',')}\\right)';
}

/// `[3,1,3]` : {3 ; 1}, sans répéter une valeur propre multiple.
String? _spectre(String latex) {
  final valeurs = _liste(latex);
  if (valeurs == null || valeurs.isEmpty) return null;
  final uniques = <String>[];
  for (final v in valeurs.map(_entier)) {
    if (!uniques.contains(v)) uniques.add(v);
  }
  return '\\left\\{${uniques.join(r'\,;\,')}\\right\\}';
}

/// `[[P,J],\mbox{true}]` : P = …, D = … ; si J n'est pas diagonale, A ne
/// l'est pas : P = …, J = …, et on le dit.
String? _diagonale(String latex, {required bool francais}) {
  final morceaux = _liste(latex);
  if (morceaux == null || morceaux.length != 2) return null;
  final matrices = _liste(morceaux[0]);
  if (matrices == null || matrices.length != 2) return null;
  final diagonalisable = morceaux[1].contains('true');
  final p = _entier(matrices[0]);
  final j = _entier(matrices[1]);
  if (diagonalisable) return 'P=$p,\\;D=$j';
  final note = francais ? 'non diagonalisable' : 'not diagonalizable';
  return 'P=$p,\\;J=$j\\;(\\text{$note})';
}

/// `\mathrm{-1}`, ainsi que Giac écrit un négatif seul : `-1`.
String _entier(String latex) => latex
    .replaceAllMapped(RegExp(r'\\mathrm\{(-[^{}]*)\}'), (m) => m[1]!)
    .trim();

/// Les lignes d'un `\begin{array}…\end{array}` de Giac, case par case.
List<List<String>>? _lignesDeTableau(String latex) {
  final tableau = RegExp(
    r'\\begin\{array\}\{[^}]*\}(.*)\\end\{array\}',
    dotAll: true,
  ).firstMatch(latex);
  if (tableau == null) return null;
  return [
    for (final ligne in tableau[1]!.split(r'\\'))
      if (ligne.trim().isNotEmpty)
        [for (final c in ligne.split('&')) _entier(c)],
  ];
}

/// `[a,[b,c]]` → `a`, `[b,c]` (virgules hors accolades, crochets, parenthèses).
List<String>? _liste(String latex) {
  final t = latex.trim();
  if (!t.startsWith('[') || !t.endsWith(']')) return null;
  final dedans = t.substring(1, t.length - 1);
  if (dedans.trim().isEmpty) return const [];
  final morceaux = <String>[];
  var profondeur = 0;
  var debut = 0;
  for (var i = 0; i < dedans.length; i++) {
    final c = dedans[i];
    if ('{[('.contains(c)) profondeur++;
    if ('}])'.contains(c)) profondeur--;
    if (c == ',' && profondeur == 0) {
      morceaux.add(dedans.substring(debut, i));
      debut = i + 1;
    }
  }
  morceaux.add(dedans.substring(debut));
  return morceaux.map((m) => m.trim()).toList();
}
