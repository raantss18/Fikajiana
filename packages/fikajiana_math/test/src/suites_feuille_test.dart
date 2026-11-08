import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:test/test.dart';

// Des suites sur plusieurs lignes d'une feuille (banc de la feuille sur le
// Pad 7, 2026-11-08) : `u_n=2n+3` puis `u_{10}=`, `w_0=2` puis
// `w_{n+1}=3w_n-4` puis `w_3=`. Valeurs de référence calculées à la main et
// avec SymPy 1.14 (`tool/banc/references_feuille.py`).

/// La valeur d'une entrée Giac sans variable : `normal` n'y change rien, et
/// pour `3w-4`, `diff(…,w)` vaut 3 et `subst(…,w=0)` vaut −4.
double _valeur(String giac) => compilerFonction(
  giac
      .replaceAll('normal(', '(')
      .replaceAll('diff(3*(w)-4,w)', '3')
      .replaceAll('subst(3*(w)-4,w=0)', '(-4)'),
)(0);

void main() {
  test('u_n=2n+3 définit la suite, u_{10}= vaut 23', () {
    final definition = analyserLatex('u_{n}=2n+3');
    expect(definition.type, TypeExpression.fonction);
    expect(definition.nomFonction, 'u');
    final dix = analyserLatex(
      'u_{10}=',
      definitions: {'u': definition.definition!},
    );
    expect(_valeur(dix.giac), 23);
    // Σ_{n=0}^{10} (2n+3) = 2·55 + 33 = 143.
    final somme = analyserLatex(
      r'\sum_{n=0}^{10}u_{n}=',
      definitions: {'u': definition.definition!},
    );
    expect(somme.giac, contains('2*n+3'));
  });

  test('w_0=2 retenu, puis le terme général de w_{n+1}=3w_n-4', () {
    final depart = analyserLatex('w_{0}=2');
    expect(depart.nomValeur, 'w_0');
    final valeurs = {depart.nomValeur!: depart.giac};
    final suite = analyserLatex('w_{n+1}=3w_{n}-4', valeurs: valeurs);
    expect(suite.type, TypeExpression.suite);
    expect(suite.giac, isNot(contains('w_0')));
    // Point fixe : 2 = 3·2 − 4, la suite est constante.
    final trois = analyserLatex(
      'w_{3}=',
      definitions: {'w': suite.definition!},
      valeurs: valeurs,
    );
    expect(_valeur(trois.giac), 2);
  });

  test('w_0=1 : w_3 = 3³·(1−2)+2 = −25', () {
    final valeurs = {'w_0': '1'};
    final suite = analyserLatex('w_{n+1}=3w_{n}-4', valeurs: valeurs);
    final trois = analyserLatex(
      'w_{3}=',
      definitions: {'w': suite.definition!},
    );
    expect(_valeur(trois.giac), -25);
  });

  test('sans premier terme, la formule garde w_0', () {
    expect(analyserLatex('w_{n+1}=3w_{n}-4').giac, contains('w_0'));
  });
}
