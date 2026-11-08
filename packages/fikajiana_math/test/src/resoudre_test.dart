import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:test/test.dart';

// Feuille d'Antsa (Pad 7, 14 h 05) : `f(x)=3e^x-x`, `k(x)=x^2`, puis
// `résoudre(f(x)=k(x))` et `f(x)=k(x)`.

void main() {
  final f = analyserLatex('f(x)=3e^{x}-x').definition!;
  final k = analyserLatex('k(x)=x^{2}').definition!;
  final definitions = {'f': f, 'k': k};

  test('f(x)=k(x), f et k définies : une équation, pas une définition', () {
    final a = analyserLatex('f(x)=k(x)', definitions: definitions);
    expect(a.type, TypeExpression.equation);
    expect(a.nomFonction, isNull);
    expect(a.giac, startsWith('solve('));
  });

  test('f(x)=2x redéfinit encore f', () {
    expect(
      analyserLatex('f(x)=2x', definitions: definitions).type,
      TypeExpression.fonction,
    );
  });

  test('résoudre(…) résout ce qui est entre parenthèses', () {
    for (final ecrit in [
      r'\text{résoudre}(f(x)=k(x))',
      r'\text{résoudre}\left(f(x)=k(x)\right)',
      'résoudre(f(x)=k(x))',
    ]) {
      final a = analyserLatex(ecrit, definitions: definitions);
      expect(a.type, TypeExpression.equation, reason: ecrit);
    }
    final sansEgal = analyserLatex(r'\text{résoudre}(x^{2}-4)');
    expect(sansEgal.type, TypeExpression.equation);
    expect(sansEgal.giac, contains('=0'));
  });
}
