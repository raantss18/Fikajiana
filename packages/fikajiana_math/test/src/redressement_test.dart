import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:test/test.dart';

void main() {
  group('lectures relevées sur le Pad 7 (2026-11-07)', () {
    void lit(String lu, String attendu, {Set<String> fonctions = const {}}) {
      test(lu, () {
        final r = redresserLecture(lu, fonctions: fonctions);
        expect(r.replaceAll(' ', ''), attendu.replaceAll(' ', ''));
        // Et le lecteur comprend ce qui sort.
        analyserLatex(r);
      });
    }

    lit(r'\frac { 1 } { 4 } ( x ) = e ^ { x } + 2', 'f(x)=e^{x}+2');
    lit('1/4(x)=e^x+2', 'f(x)=e^x+2');
    lit('f^1(x)=', "f'(x)=");
    lit('f ^ { 1 } ( x ) =', "f'(x)=");
    lit(r'g ^ { \prime } ( x ) =', "g'(x)=");
    lit('g^((x))=0', 'g(x)=0');
    lit('g ^ { ( x ) } = 0', 'g(x)=0');
    lit('g ( x ) = 3 x - 5 0 ^ { x }', 'g(x)=3x-5e^{x}');
    lit('9(x)=3x-5', 'g(x)=3x-5');
    lit('8(x)=0', 'g(x)=0', fonctions: {'g'});
    lit("9'(x)=", "g'(x)=");
    lit('7 ^ { 1 } ( x ) =', "f'(x)=");
  });

  group('ce qui a du sens ne bouge pas', () {
    void reste(String lu) {
      test(lu, () {
        expect(
          redresserLecture(lu).replaceAll(' ', ''),
          lu.replaceAll(' ', ''),
        );
      });
    }

    reste('10^x');
    reste('100^{x}');
    reste('2^x');
    reste('e^{x}');
    reste('x^{2}+1=0');
    reste('9(x+1)=3');
    reste('8(x)=16');
    reste('3(x)=9');
    reste('2(x+1)');
    reste('f(x)=x^{2}');
    reste(r'\frac{1}{4}(x+1)');
    reste('f^{2}(x)');
    reste('x^{(x)}');
    reste('a^1');
  });

  test('toute la chaîne : g(x) puis sa dérivée et son équation', () {
    final g = analyserLatex(redresserLecture('g ( x ) = 3 x - 5 0 ^ { x }'));
    expect(g.nomFonction, 'g');
    final defs = {'g': g.definition!};
    final derivee = analyserLatex(
      redresserLecture('g ^ { 1 } ( x ) ='),
      definitions: defs,
    );
    expect(derivee.giac, contains('diff('));
    final equation = analyserLatex(
      redresserLecture('g^((x))=0', fonctions: {'g'}),
      definitions: defs,
    );
    expect(equation.type, TypeExpression.equation);
  });
}
