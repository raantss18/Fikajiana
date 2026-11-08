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

  group('relevées le 7 novembre, deuxième essai', () {
    test('le déterminant lu alpha + binomial', () {
      final r = redresserLecture(r'\alpha + \binom { 2 5 } { - 1 - 3 } =');
      final a = analyserLatex(r);
      expect(a.giac, 'det([[2,5],[(-1),(-3)]])');
      expect(a.demandeResultat, isTrue);
    });
    test('le déterminant lu d e t', () {
      final r = redresserLecture(
        r'd e t \begin{pmatrix} 1 & 5 \\ - 1 & 8 \end{pmatrix}',
      );
      expect(analyserLatex(r).giac, startsWith('det('));
    });
    test('le point lu A(1/2)', () {
      for (final lu in [
        'A(1/2)',
        'A ( 1 / 2 )',
        r'A \left( \frac { 1 } { 2 } \right)',
      ]) {
        final o = lireObjet(redresserLecture(lu));
        expect(o, isA<PointLu>(), reason: lu);
        expect((o!.x, o.y), (1, 2), reason: lu);
      }
    });
    test('un vecteur en colonne lu comme un binomial', () {
      final o = lireObjet(r'\overrightarrow { A B } \binom { 1 } { 3 }');
      expect(o, isA<VecteurLu>());
      expect((o!.nom, o.x, o.y), ('AB', 1, 3));
    });
  });

  group('un binomial reste un binomial', () {
    void reste(String lu) {
      test(lu, () => expect(redresserLecture(lu), lu));
    }

    reste(r'\binom{10}{2}');
    reste(r'\binom{n}{k}');
    reste(r'\binom{5}{2}');
    reste(r'\alpha+1');
    reste('f(1/2)');
    reste('a(1/2)');
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

  group('relevées sur le téléphone d’Antsa (2026-11-07)', () {
    test('le 9 lu g (Pad 7)', () {
      expect(
        redresserLecture(r'3+\frac{1}{3}+\frac{1}{g}'),
        r'3+\frac{1}{3}+\frac{1}{9}',
      );
      expect(redresserLecture('g^{2}'), '9^{2}');
      expect(redresserLecture('g^{2}', fonctions: {'g'}), 'g^{2}');
      expect(redresserLecture('g(x)=3x'), 'g(x)=3x');
      expect(redresserLecture(r'\log(2)'), r'\log(2)');
    });

    test(r'feuille du Pad 7 (9 h 43) : \rightarrow garde sa flèche', () {
      expect(
        sansLeftRight(r'\lim_{x \rightarrow 3}'),
        r'\lim_{x \rightarrow 3}',
      );
      expect(sansLeftRight(r'\left( x \right)'), '( x )');
      expect(
        redresserLecture(r'\lim _ { x \rightarrow 1 } \frac{1}{x}='),
        r'\lim _ { x \rightarrow 1 } \frac{1}{x}=',
      );
    });

    test('feuille du Pad 7 (9 h 43) : le point après le = final', () {
      expect(
        redresserLecture(
          r'\left( \begin{matrix} 1 \end{matrix} \right) '
          r'\left( \begin{matrix} 2 \end{matrix} \right) = .',
        ),
        r'( \begin{matrix} 1 \end{matrix} ) ( \begin{matrix} 2 \end{matrix} ) =',
      );
      expect(redresserLecture('1,5=1.5'), '1,5=1.5');
    });

    test('le 1 lu Λ', () {
      expect(redresserLecture(r'\varLambda + \varLambda'), '1+ 1');
      expect(redresserLecture(r'\Lambda 0 \times 3'), r'10 \times 3');
    });
  });
}
