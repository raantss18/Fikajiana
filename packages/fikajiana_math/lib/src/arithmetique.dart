/// L'arithmétique du lycée écrite comme au tableau (vague 2 de
/// `docs/recherche/couverture-calcul.md`) :
///
/// - `division(17;5)` : quotient et reste de la division euclidienne
///   (Giac `iquo`, `irem` : <https://www-fourier.univ-grenoble-alpes.fr/~parisse/giac/doc/fr/cascmd_fr/cascmd_fr171.html>) ;
/// - `bezout(12;18)` : u, v et le pgcd d tels que 12u + 18v = d (Giac
///   `iegcd`) ;
/// - `17 \equiv 2 [5]`, `17\equiv 2\pmod{5}` : vrai ou faux.
///
/// `quotient(a;b)`, `reste(a;b)` et `A_n^k` passent par le lecteur.
library;

import 'package:fikajiana_math/src/analyse.dart';
import 'package:fikajiana_math/src/redressement.dart' show sansLeftRight;

/// `A_{5}^{2}` (arrangements, notation du lycée) : `perm(5;2)` pour le
/// lecteur. Seulement avec deux nombres : une matrice A_1 reste A_1.
String avecArrangements(String latex) => latex.replaceAllMapped(
  RegExp(r'(?<![A-Za-z\\])A_\{?(\d+)\}?\^\{?(\d+)\}?'),
  (m) => '\\operatorname{perm}(${m[1]};${m[2]})',
);

String _nu(String latex) => sansLeftRight(latex)
    .replaceAllMapped(
      RegExp(
        r'\\(?:mathrm|operatorname|text|textrm|textit)\s*\{\s*([^{}]*?)\s*\}',
      ),
      (m) => m[1]!,
    )
    .replaceAll(RegExp(r'\\[,;:!]|\\quad'), '')
    .replaceAll(RegExp(r'\s+'), '')
    .trim();

/// Coupe `a;b` (ou `a,b` faute de `;`) en deux morceaux, hors parenthèses.
(String, String)? _deux(String dedans) {
  for (final signe in [';', ',']) {
    var profondeur = 0;
    for (var i = 0; i < dedans.length; i++) {
      final c = dedans[i];
      if ('({['.contains(c)) profondeur++;
      if (')}]'.contains(c)) profondeur--;
      if (c == signe && profondeur == 0) {
        final reste = dedans.substring(i + 1);
        if (reste.contains(signe)) return null;
        return (dedans.substring(0, i), reste);
      }
    }
  }
  return null;
}

/// `division(17;5)`, `bezout(12;18)`, `17\equiv 2[5]` : une ligne
/// d'arithmétique, ou `null`.
Analyse? analyserArithmetique(
  String latex, {
  Map<String, String> valeurs = const {},
}) {
  final ligne = _nu(latex);
  String giac(String t) => analyserLatex(t, valeurs: valeurs).giac;

  final appel = RegExp(
    r'^(division|divisioneuclidienne|bezout|bézout)\((.*)\)=?$',
  ).firstMatch(ligne);
  if (appel != null) {
    final arguments = _deux(appel[2]!);
    if (arguments == null) {
      throw const ErreurLatex('deux nombres attendus : division(a;b)');
    }
    final (a, b) = (giac(arguments.$1), giac(arguments.$2));
    if (appel[1]!.startsWith('division')) {
      // Le reste toujours positif : 17 = 5×3 + 2, −17 = 5×(−4) + 3.
      final q = 'floor(($a)/($b))';
      return Analyse(
        TypeExpression.systeme,
        '[[$q,($a)-($b)*$q]]',
        inconnues: const ['q', 'r'],
      );
    }
    return Analyse(
      TypeExpression.systeme,
      '[iegcd($a,$b)]',
      inconnues: const ['u', 'v', 'd'],
    );
  }

  // a ≡ b [n], a ≡ b (mod n), a ≡ b \pmod{n}.
  final congruence = RegExp(
    r'^(.+)\\equiv(.+?)(?:\\pmod\{(.+)\}|\\pmod(\d+)|\[(.+)\]|\((?:\\bmod|\\mod|mod)(.+)\)|(?:\\bmod|\\mod|mod)(.+))$',
  ).firstMatch(ligne);
  if (congruence == null) return null;
  final n = [
    3,
    4,
    5,
    6,
    7,
  ].map((i) => congruence[i]).firstWhere((t) => t != null)!;
  final a = analyserLatex(congruence[1]!, valeurs: valeurs);
  final b = analyserLatex(congruence[2]!, valeurs: valeurs);
  if (a.inconnues.isNotEmpty ||
      b.inconnues.isNotEmpty ||
      RegExp('[a-zA-Z]')
          .hasMatch('${a.giac}${b.giac}'.replaceAll(RegExp(r'[a-z]+\('), ''))) {
    throw const ErreurLatex('congruence : des nombres attendus');
  }
  return Analyse(
    TypeExpression.calcul,
    'irem((${a.giac})-(${b.giac}),${giac(n)})==0',
  );
}
