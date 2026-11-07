import 'dart:math' as math;

import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:test/test.dart';

/// Giac reçoit la même valeur que la référence, calculée à la main.
void vaut(String texte, double attendu, {double x = 1.7}) {
  test('$texte vaut $attendu en x=$x', () {
    final saisie = lireSaisie(texte);
    expect(saisie.latex, isNotNull, reason: '${saisie.probleme}');
    final giac = analyserLatex(saisie.latex!).giac;
    expect(compilerFonction(giac)(x), closeTo(attendu, 1e-9), reason: giac);
  });
}

void main() {
  const x = 1.7;
  group('ce qu’on tape se comprend', () {
    vaut('2+3', 5);
    vaut('1/3', 1 / 3);
    vaut('3,5+1', 4.5);
    vaut('3.5+1', 4.5);
    vaut('2,5x', 2.5 * x);
    vaut('2x', 2 * x);
    vaut('2 x', 2 * x);
    vaut('x²', x * x);
    vaut('x^2', x * x);
    vaut('x**2', x * x);
    vaut('x^-1', 1 / x);
    vaut('x^(1/2)', 1.3038404810405297);
    vaut('x^2x', x * x * x);
    vaut('2^3^2', 512);
    vaut('sqrt(2)', math.sqrt2);
    vaut('sqrt 2', math.sqrt2);
    vaut('√2', math.sqrt2);
    vaut('√(x+1)/2', math.sqrt(x + 1) / 2);
    vaut('racine de 2', math.sqrt2);
    vaut('racine carrée de 2', math.sqrt2);
    vaut('racine(2)', math.sqrt2);
    vaut('pi', math.pi);
    vaut('π', math.pi);
    vaut('2pi', 2 * math.pi);
    vaut('sin x', math.sin(x));
    vaut('sinx', math.sin(x));
    vaut('sin(x)', math.sin(x));
    vaut('sin 2x', math.sin(2 * x));
    vaut('sin x^2', math.sin(x * x));
    vaut('sin^2 x', math.pow(math.sin(x), 2).toDouble());
    vaut('sin(x)^2', math.pow(math.sin(x), 2).toDouble());
    vaut('sin 2pi x', math.sin(2 * math.pi * x));
    vaut('sin x + 1', math.sin(x) + 1);
    vaut('sin x cos x', math.sin(x) * math.cos(x));
    vaut('2 sin x', 2 * math.sin(x));
    vaut('cos -x', math.cos(-x));
    vaut('arctan 1', math.pi / 4);
    vaut('atan(1)', math.pi / 4);
    vaut('ln(5)', math.log(5));
    vaut('ln 5', math.log(5));
    vaut('exp(1)', math.e);
    vaut('e^x', math.exp(x));
    vaut('abs(-x)', x);
    vaut('|x-3|', 3 - x);
    vaut('(x+1)(x-1)', (x + 1) * (x - 1));
    vaut('2(x+1)', 2 * (x + 1));
    vaut('x(x+1)', x * (x + 1));
    vaut('-x+2', 2 - x);
    vaut('--x', x);
    vaut('2*-x', -2 * x);
    vaut('2×3', 6);
    vaut('6÷2', 3);
    vaut('2−1', 1);
    vaut('(x+1', x + 1);
    vaut('sqrt(x+1', math.sqrt(x + 1));
    vaut('1/x+1', 1 / x + 1);
    vaut('(x+1)/(x-1)', (x + 1) / (x - 1));
  });

  group('1/2x', () {
    vaut('1/2x', x / 2);
    test('propose l’autre lecture', () {
      final s = lireSaisie('1/2x');
      expect(s.latex, r'\frac{1}{2}x');
      expect(s.autreLecture, r'\frac{1}{2x}');
      final giac = analyserLatex(s.autreLecture!).giac;
      expect(compilerFonction(giac)(x), closeTo(1 / (2 * x), 1e-9));
    });
    test('l’espace lève le doute', () {
      expect(lireSaisie('1/2 x').autreLecture, isNull);
      expect(lireSaisie('1/2').autreLecture, isNull);
      expect(lireSaisie('x/2+1').autreLecture, isNull);
    });
  });

  group('la forme compte', () {
    TypeExpression type(String t) => analyserLatex(lireSaisie(t).latex!).type;
    test('équation, fonction, calcul', () {
      expect(type('x^2+3x-5=0'), TypeExpression.equation);
      expect(type('x²=2'), TypeExpression.equation);
      expect(type('2+3='), TypeExpression.calcul);
      expect(type('f(x)=x^2'), TypeExpression.fonction);
      expect(type('y=2x+1'), TypeExpression.fonction);
      expect(type('k(x)=x^2'), TypeExpression.fonction);
    });
    test('la factorielle', () {
      expect(analyserLatex(lireSaisie('3!').latex!).giac, 'factorial(3)');
    });
    test('k(x)= définit k, et son corps est juste', () {
      final a = analyserLatex(lireSaisie('k(x)=x^2').latex!);
      expect(a.giac, 'k(x):=(x)^(2)');
    });
    test('l’écriture à la main aussi', () {
      expect(analyserLatex('k(x)=x^{2}').type, TypeExpression.fonction);
      expect(analyserLatex(r'\sin 2x').giac, 'sin(2*x)');
      expect(analyserLatex(r'\sin 2\pi x').giac, 'sin(2*pi*x)');
      expect(analyserLatex(r'\sin x \cos x').giac, 'sin(x)*cos(x)');
      expect(analyserLatex(r'\int \sin x dx').giac, 'normal(integrate(sin(x),x))');
      expect(
        analyserLatex(r'\int_0^1 \sin 2x dx').giac,
        'integrate(sin(2*x),x,0,1)',
      );
    });
    test('les bornes sans accolades ne sont pas des puissances', () {
      expect(analyserLatex(r'\int_0^1 x dx').giac, 'integrate(x,x,0,1)');
      expect(analyserLatex(r'\int_{0}^{1} x dx').giac, 'integrate(x,x,0,1)');
      expect(analyserLatex(r'\int_-1^1 x dx').giac, 'integrate(x,x,(-1),1)');
    });
    test('une équation à une lettre reste une équation', () {
      expect(analyserLatex('x(x)=2').type, TypeExpression.equation);
    });
  });

  group('rien n’est deviné en silence', () {
    void refuse(String t, ProblemeSaisie p) {
      test('$t est refusé', () {
        expect(lireSaisie(t).latex, isNull);
        expect(lireSaisie(t).probleme, p);
      });
    }

    refuse('hello', ProblemeSaisie.motInconnu);
    refuse('racines', ProblemeSaisie.motInconnu);
    refuse('dérivée', ProblemeSaisie.motInconnu);
    refuse('2 3', ProblemeSaisie.nombresColles);
    refuse('1 000', ProblemeSaisie.nombresColles);
    refuse('2+', ProblemeSaisie.incomplet);
    refuse('x^', ProblemeSaisie.incomplet);
    refuse('sqrt', ProblemeSaisie.incomplet);
    refuse('', ProblemeSaisie.incomplet);
    refuse('2)', ProblemeSaisie.signeInattendu);
    refuse('2+*3', ProblemeSaisie.signeInattendu);
    test('le mot en cause est dit', () {
      expect(lireSaisie('hello').detail, 'hello');
    });
  });

  group('le LaTeX reste accepté', () {
    test('passe tel quel', () {
      expect(lireSaisie(r'\frac{1}{3}').latex, r'\frac{1}{3}');
      expect(lireSaisie('x^{2}').latex, 'x^{2}');
    });
  });

  group('du LaTeX lu au texte à corriger', () {
    void revient(String latex, String texte) {
      test(latex, () {
        expect(texteDepuisLatex(latex), texte);
        final a = analyserLatex(latex).giac;
        final b = analyserLatex(lireSaisie(texte).latex!).giac;
        expect(
          compilerFonction(b)(x),
          closeTo(compilerFonction(a)(x), 1e-9),
          reason: '$a / $b',
        );
      });
    }

    revient('x ^ { 2 } + 3 x - 5', 'x^2+3x-5');
    revient(r'\frac { 1 } { 3 }', '1/3');
    revient(r'\frac { x + 1 } { 2 }', '(x+1)/2');
    revient(r'\sqrt { 2 9 } - 3', 'sqrt(29)-3');
    revient(r'\sin \left( 2 x \right)', 'sin(2x)');
    revient(r'2 \cdot \pi', '2*pi');
    revient('x ^ { x + 1 }', 'x^(x+1)');
    test('ce qui ne s’écrit pas simplement reste en LaTeX', () {
      const somme = r'\sum_{k=1}^{3}k';
      expect(texteDepuisLatex(somme), somme);
    });
  });
}
