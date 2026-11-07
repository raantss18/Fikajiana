import 'package:fikajiana/comprendre/solutions.dart';
import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter_test/flutter_test.dart';

// Les entrées sont les sorties réelles de Giac (commit 19a710a), relevées sur
// l'émulateur le 2026-11-06.
String _equation(String latex, {String inconnue = 'x', bool francais = true}) =>
    ecrireSolutions(
      latex,
      type: TypeExpression.equation,
      inconnues: [inconnue],
      francais: francais,
    );

void main() {
  group('équation', () {
    test('une solution, sans accolades ni faux signe égal', () {
      expect(_equation(r'\{1\}'), 'x=1');
    });

    test('plusieurs solutions', () {
      expect(
        _equation(r'\{-\sqrt{2},\sqrt{2}\}'),
        r'x=-\sqrt{2}\,\mathrm{ou}\,x=\sqrt{2}',
      );
      expect(_equation(r'\{0,1\}', francais: false), contains('or'));
    });

    test('une virgule dans une sous-expression ne coupe pas', () {
      expect(_equation(r'\{\frac{1}{f(a,b)}\}'), r'x=\frac{1}{f(a,b)}');
    });

    test('une suite : son terme général, nommé', () {
      expect(
        ecrireSolutions(
          '2^{n}',
          type: TypeExpression.suite,
          inconnues: const ['u_n'],
          francais: true,
        ),
        'u_n=2^{n}',
      );
    });

    group('inéquations, sorties réelles de Giac', () {
      test('une relation reste telle quelle', () {
        expect(_equation(r'\{x>2\}'), 'x>2');
        expect(_equation(r'\{x\geq 1\}'), r'x\geq 1');
      });

      test('deux bornes s’écrivent en une seule ligne', () {
        expect(_equation(r'\{(x>\mathrm{-2})\mbox{ and }(x<2)\}'), '-2<x<2');
        expect(
          _equation(r'\{(x\geq \mathrm{-1})\mbox{ and }(x\leq 1)\}'),
          r'-1\leq x\leq 1',
        );
      });

      test('deux intervalles se disent avec « ou »', () {
        expect(
          _equation(r'\{x\leq \mathrm{-1},x\geq 1\}'),
          r'x\leq -1\,\mathrm{ou}\,x\geq 1',
        );
      });

      test('sans solution', () {
        expect(_equation('[]'), r'S=\emptyset');
      });
    });

    test('aucune solution', () {
      expect(_equation('[]'), r'S=\emptyset');
    });

    test('tous les réels', () {
      expect(_equation(r'\{x\}'), r'S=\mathbb{R}');
    });

    test('une famille de solutions dit que n est entier', () {
      expect(
        _equation(r'\{\mathrm{n\_0}\cdot \pi \}'),
        r'x=n\cdot \pi,\,n \in \mathbb{Z}',
      );
    });

    test('une inconnue grecque', () {
      expect(_equation(r'\{1\}', inconnue: 'theta'), r'\theta=1');
    });

    test('une forme inattendue reste telle quelle', () {
      expect(_equation('5'), '5');
    });
  });

  group('système', () {
    String systeme(String latex) => ecrireSolutions(
      latex,
      type: TypeExpression.systeme,
      inconnues: const ['x', 'y'],
      francais: true,
    );

    test('une solution', () {
      expect(
        systeme(
          r'\left(\begin{array}{cc}'
          '\n'
          r'2 & \mathrm{-1}'
          '\n'
          r'\end{array}\right) ',
        ),
        r'x=2\,\mathrm{et}\,y=\mathrm{-1}',
      );
    });

    test('aucune solution', () {
      expect(systeme('[]'), r'S=\emptyset');
    });

    test('un autre nombre de valeurs reste tel quel', () {
      const latex = r'\left(\begin{array}{c}1\end{array}\right)';
      expect(systeme(latex), latex);
    });
  });
}
