import 'package:fikajiana/moteur/giac.dart';
import 'package:fikajiana/moteur/moteur.dart';

/// Pourquoi une ligne suit la précédente : la phrase dite à côté d'elle.
enum RaisonEtape {
  /// L'équation telle qu'elle est écrite.
  depart,

  /// Tout dans le membre de gauche, développé et réduit.
  toutAGauche,

  /// Les termes sans l'inconnue passent à droite.
  isoler,

  /// On divise par le coefficient de l'inconnue.
  diviser,

  /// On lit a, b et c.
  coefficients,

  /// Δ = b² − 4ac.
  discriminant,

  /// Δ > 0 : deux solutions.
  deuxSolutions,

  /// Δ = 0 : une solution double.
  solutionDouble,

  /// Δ < 0 : pas de solution réelle.
  aucuneSolution,

  /// La première, puis la seconde solution.
  premiere,
  seconde,

  /// L'ensemble des solutions.
  conclusion,
}

/// Une ligne de la résolution, et sa raison.
class Etape {
  const new(this.raison, this.latex);

  final RaisonEtape raison;
  final String latex;

  @override
  String toString() => '${raison.name} : $latex';
}

/// Les étapes de la résolution de `gauche = droite` en [x], comme un
/// professeur les écrit au tableau : degré 1, ou degré 2 par le discriminant
/// (programme de première, https://eduscol.education.gouv.fr/document/24553/download).
///
/// Giac fait chaque calcul ; rien n'est simplifié à la main. Rend `null` si
/// l'équation n'est pas un polynôme de degré 1 ou 2 à coefficients
/// numériques : pas d'étapes plutôt que des étapes fausses.
Future<List<Etape>?> etapesEquation(
  Moteur moteur, {
  required String ecrit,
  required String gauche,
  required String droite,
  required String x,
}) async {
  Future<ReponseGiac?> giac(String entree) async {
    final r = await moteur.calculer(entree);
    if (r.arrete || r.erreur != null || r.exact.trim().isEmpty) return null;
    // Comme au tableau : `-5` et `2x`, pas `\mathrm{-5}` ni `2\cdot x`.
    final latex = r.latex
        .replaceAllMapped(RegExp(r'\\mathrm\{(-[0-9.,]+)\}'), (m) => m[1]!)
        .replaceAllMapped(
          RegExp(r'(\d|\}) ?\\cdot ([a-zA-Z])'),
          (m) => '${m[1]}${m[2]}',
        );
    return ReponseGiac(exact: r.exact, latex: latex, approche: r.approche);
  }

  final p = '(($gauche)-($droite))';
  final degre = await giac('degree(expand($p),$x)');
  final n = int.tryParse(degre?.exact.trim() ?? '');
  if (n != 1 && n != 2) return null;
  // Les coefficients, du plus haut degré à la constante, tous numériques.
  final coefficients = <ReponseGiac>[];
  for (var k = n!; k >= 0; k--) {
    final c = await giac('coeff(expand($p),$x,$k)');
    if (c == null || double.tryParse(c.approche) == null) return null;
    coefficients.add(c);
  }
  final reduit = await giac('expand($p)');
  if (reduit == null) return null;
  // Entre parenthèses dès qu'un signe ou une opération s'y trouve.
  String entre(ReponseGiac c) => RegExp(r'^[0-9.,]+$').hasMatch(c.latex)
      ? c.latex
      : '\\left(${c.latex}\\right)';

  final etapes = <Etape>[Etape(RaisonEtape.depart, ecrit)];
  final dejaReduit = droite.trim() == '0' && reduit.exact == gauche.trim();
  if (!dejaReduit) {
    etapes.add(Etape(RaisonEtape.toutAGauche, '${reduit.latex}=0'));
  }

  if (n == 1) {
    final [a, b] = coefficients;
    final ax = await giac('(${a.exact})*$x');
    final moinsB = await giac('-(${b.exact})');
    final solution = await giac('-(${b.exact})/(${a.exact})');
    if (ax == null || moinsB == null || solution == null) return null;
    if (double.parse(b.approche) != 0) {
      etapes.add(Etape(RaisonEtape.isoler, '${ax.latex}=${moinsB.latex}'));
    }
    if (double.parse(a.approche) != 1) {
      etapes.add(
        Etape(RaisonEtape.diviser, '$x=\\frac{${moinsB.latex}}{${a.latex}}'),
      );
    }
    etapes.add(Etape(RaisonEtape.conclusion, '$x=${solution.latex}'));
    return etapes;
  }

  final [a, b, c] = coefficients;
  etapes.add(
    Etape(
      RaisonEtape.coefficients,
      'a=${a.latex},\\ b=${b.latex},\\ c=${c.latex}',
    ),
  );
  final delta = await giac('(${b.exact})^2-4*(${a.exact})*(${c.exact})');
  final signe = double.tryParse(delta?.approche ?? '');
  if (delta == null || signe == null) return null;
  etapes.add(
    Etape(
      RaisonEtape.discriminant,
      '\\Delta=b^{2}-4ac=${entre(b)}^{2}-4\\times ${entre(a)}\\times '
      '${entre(c)}=${delta.latex}',
    ),
  );
  if (signe < 0) {
    etapes.add(const Etape(RaisonEtape.aucuneSolution, r'\Delta<0'));
    return etapes;
  }
  if (signe == 0) {
    final x0 = await giac('-(${b.exact})/(2*(${a.exact}))');
    if (x0 == null) return null;
    etapes
      ..add(
        Etape(
          RaisonEtape.solutionDouble,
          '${x}_{0}=\\frac{-b}{2a}=${x0.latex}',
        ),
      )
      ..add(Etape(RaisonEtape.conclusion, '$x=${x0.latex}'));
    return etapes;
  }
  final x1 = await giac(
    'simplify((-(${b.exact})-sqrt(${delta.exact}))/(2*(${a.exact})))',
  );
  final x2 = await giac(
    'simplify((-(${b.exact})+sqrt(${delta.exact}))/(2*(${a.exact})))',
  );
  if (x1 == null || x2 == null) return null;
  etapes
    ..add(const Etape(RaisonEtape.deuxSolutions, r'\Delta>0'))
    ..add(
      Etape(
        RaisonEtape.premiere,
        '${x}_{1}=\\frac{-b-\\sqrt{\\Delta}}{2a}=${x1.latex}',
      ),
    )
    ..add(
      Etape(
        RaisonEtape.seconde,
        '${x}_{2}=\\frac{-b+\\sqrt{\\Delta}}{2a}=${x2.latex}',
      ),
    )
    ..add(
      Etape(
        RaisonEtape.conclusion,
        '$x=${x1.latex}\\ \\text{ou}\\ $x=${x2.latex}',
      ),
    );
  return etapes;
}
