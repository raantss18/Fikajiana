import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:test/test.dart';

void main() {
  void giac(String latex, String attendu, [TypeExpression? type]) {
    test(latex, () {
      final analyse = analyserLatex(latex);
      expect(analyse.giac, attendu);
      if (type != null) expect(analyse.type, type);
    });
  }

  test('une équation et un système disent leurs inconnues', () {
    expect(analyserLatex('x+3=4').inconnues, ['x']);
    expect(analyserLatex(r'\begin{cases}x+y=1\\x-y=3\end{cases}').inconnues, [
      'x',
      'y',
    ]);
    expect(analyserLatex('2+3=').inconnues, isEmpty);
  });

  test('une fonction dit son corps et sa variable', () {
    final f = analyserLatex('f(x)=x^{2}');
    expect(f.corps, '(x)^(2)');
    expect(f.inconnues, ['x']);
    final y = analyserLatex('y=3x+2');
    expect(y.type, TypeExpression.fonction);
    expect(y.corps, '3*x+2');
    expect(y.inconnues, ['x']);
    expect(analyserLatex('y=2').type, TypeExpression.equation);
    expect(analyserLatex('y=x+y').type, TypeExpression.equation);
  });

  group('noms de fonctions lus', () {
    giac(r'\sin ( \pi )', 'sin(pi)');
    giac(r'\ln ( 5 ) =', 'ln(5)');
    giac('l n ( 5 )', 'ln(5)');
    giac('s i n ( x )', 'sin(x)');
    giac(r'\operatorname { s i n } ( x )', 'sin(x)');
    giac(r'\operatorname{ln}(5)', 'ln(5)');
    giac(r'\mathrm { l n } ( 5 )', 'ln(5)');
    giac('I n ( 5 )', 'ln(5)');
  });

  group('degrés', () {
    test('30° vaut π/6 en radians', () {
      const attendu = 'sin((30)*pi/180)';
      expect(analyserLatex(r'\sin ( 3 0 ^ { \circ } )').giac, attendu);
      expect(analyserLatex(r'\sin(30^\circ)').giac, attendu);
      expect(analyserLatex(r'\sin(30°)').giac, attendu);
    });

    test('30° reste 30 quand Giac compte en degrés', () {
      expect(analyserLatex(r'\sin(30°)', degres: true).giac, 'sin(30)');
    });
  });

  group('calculs', () {
    giac('2+3', '2+3', TypeExpression.calcul);
    giac('2+3=', '2+3', TypeExpression.calcul);
    giac('2 + 3 =', '2+3', TypeExpression.calcul);
    giac(r'2 \times 3', '2*3');
    giac(r'2 \cdot 3', '2*3');
    giac('3,14+1', '3.14+1');
    giac('-2+3', '(-2)+3');
    giac('2x+3', '2*x+3');
    giac('2(x+1)', '2*(x+1)');
    giac(r'\frac { 1 } { 2 }', '(1)/(2)');
    giac(r'\frac { 3 } { 4 } + \frac { 1 } { 6 }', '(3)/(4)+(1)/(6)');
    giac(r'1+\frac{1}{1+\frac{1}{x}}', '1+(1)/(1+(1)/(x))');
    giac('2 ^ { 1 0 }', '(2)^(10)');
    giac('x^2', '(x)^(2)');
    giac('e^{-x^{2}}', '(e)^((-(x)^(2)))');
    giac(r'\sqrt { 2 }', 'sqrt(2)');
    giac(r'\sqrt[3]{8}', '(8)^(1/(3))');
    giac(r'\sin ( x )', 'sin(x)');
    giac(r'\sin x', 'sin(x)');
    giac(r'\sin^{2} x', '(sin(x))^(2)');
    giac(r'\ln(x)', 'ln(x)');
    giac(r'\log(100)', 'log10(100)');
    giac('|x-1|', 'abs(x-1)');
    giac('5!', 'factorial(5)');
    giac(r'\pi', 'pi');
    giac(r'\left( x \right)', '(x)');
    giac(r'{ \bf x } + 1', 'x+1');
    giac('1 0 + 2 5', '10+25');
    giac('3 . 1 4', '3.14');
  });

  group('analyse des grandes opérations', () {
    giac(r'\int x\,dx', 'integrate(x,x)');
    giac(r'\int_{0}^{1}x^{2}\,dx', 'integrate((x)^(2),x,0,1)');
    giac(r'\int _ { 0 } ^ { \pi } \sin ( x ) d x', 'integrate(sin(x),x,0,pi)');
    giac(r'\int_{1}^{e}\frac{1}{x}\,dx', 'integrate((1)/(x),x,1,e)');
    giac(r'\int_{0}^{+\infty}e^{-t}\,dt', 'integrate((e)^((-t)),t,0,inf)');
    giac(r'\lim_{x\to0}\frac{\sin(x)}{x}', 'limit((sin(x))/(x),x,0)');
    giac(
      r'\lim _ { n \rightarrow + \infty } \frac { 1 } { n }',
      'limit((1)/(n),n,inf)',
    );
    giac(r'\sum_{k=1}^{n}k', 'sum(k,k,1,n)');
    giac(r'\sum_{n=1}^{+\infty}\frac{1}{n^{2}}', 'sum((1)/((n)^(2)),n,1,inf)');
    giac(r'\prod_{k=1}^{n}k', 'product(k,k,1,n)');
  });

  group('matrices', () {
    giac(
      r'\begin{pmatrix}1&2\\3&4\end{pmatrix}',
      '[[1,2],[3,4]]',
      TypeExpression.matrice,
    );
    giac(
      r'\left( \begin{matrix} { 2 } & { - 1 } \\ { 0 } & { 3 } \\ \end{matrix} \right)',
      '[[2,(-1)],[0,3]]',
      TypeExpression.matrice,
    );
    giac(
      r'\left( \begin{array} { c c } { 1 } & { 0 } \\ { 0 } & { 1 } \\ \end{array} \right)',
      '[[1,0],[0,1]]',
      TypeExpression.matrice,
    );
  });

  group('équations et systèmes', () {
    giac('x^2=2', 'solve((x)^(2)=2,x)', TypeExpression.equation);
    giac('2x+1=5', 'solve(2*x+1=5,x)', TypeExpression.equation);
    giac('2+2=5', 'normal((2+2)-(5))==0', TypeExpression.calcul);
    giac(
      r'\begin{cases}x+y=1\\x-y=3\end{cases}',
      'solve([x+y=1,x-y=3],[x,y])',
      TypeExpression.systeme,
    );
    giac(
      r'\left\{ \begin{matrix} x + y = 1 \\ x - y = 3 \end{matrix} \right.',
      'solve([x+y=1,x-y=3],[x,y])',
      TypeExpression.systeme,
    );
  });

  group('fonctions', () {
    giac('f(x)=x^{2}', 'f(x):=(x)^(2)', TypeExpression.fonction);
    giac(
      r'g ( t ) = \sin ( t ) + \cos ( t )',
      'g(t):=sin(t)+cos(t)',
      TypeExpression.fonction,
    );
    giac('f(2)', 'f(2)', TypeExpression.calcul);
    giac('x(x+1)', 'x*(x+1)');
  });

  group('bornes sans accolades : un seul signe, comme en LaTeX', () {
    giac(r'\int_0^1 x^2 dx', 'integrate((x)^(2),x,0,1)');
    giac(r'\int_0^{+\infty} e^{-x} dx', 'integrate((e)^((-x)),x,0,inf)');
    giac(r'\sum_{k=1}^n k', 'sum(k,k,1,n)');
    giac('x_1^2', '(x_1)^(2)');
    giac(r'\frac12', '(1)/(2)');
    giac(r'\sin(x)=\frac12', 'solve(sin(x)=(1)/(2),x)');
    giac(r'\log_2 8', 'simplify(ln(8)/ln(2))');
  });

  group('dérivées', () {
    giac(r'\frac{d}{dx}(x^2)', 'diff(((x)^(2)),x)');
    giac(r'\frac{d}{dx}x^3', 'diff((x)^(3),x)');
    giac(r'\frac{d^2}{dx^2}x^3', 'diff((x)^(3),x,2)');
    giac(r'\frac{d(x^2)}{dx}', 'diff(((x)^(2)),x)');
    giac(r'\frac{\mathrm{d}}{\mathrm{d}x}x', 'diff(x,x)');
    giac(r'\frac{\partial}{\partial x}(x y)', 'diff((x*y),x)');
    giac(r'\frac{df}{dx}', 'diff(f(x),x)');
    giac("(x^2)'", 'diff(((x)^(2)),x)');
    giac(r"(\sin(x))''", 'diff((sin(x)),x,2)');
    giac("f'(x)", "f'(x)");
    giac("f''(2)", "f''(2)");
    giac(r'f^{\prime}(x)', "f'(x)");
    giac(r'f^\prime(2)', "f'(2)");
    giac(r'\frac{d}{e}', '(d)/(e)');
    giac(r'\frac{2}{dx}', '(2)/(d*x)');
  });

  group('fonctions usuelles et nommées', () {
    giac(r'\binom{5}{2}', 'comb(5,2)');
    giac('C_5^2', 'comb(5,2)');
    giac('A_5^2', 'perm(5,2)');
    giac(r'\gcd(12,18)', 'gcd(12,18)');
    giac(r'\operatorname{pgcd}(12;18)', 'gcd(12,18)');
    giac(r'\text{ppcm}(4,6)', 'lcm(4,6)');
    giac('p g c d ( 1 2 , 1 8 )', 'gcd(12,18)');
    giac(r'17 \bmod 5', '((17)-(5)*floor((17)/(5)))');
    giac(r'\lfloor x \rfloor', 'floor(x)');
    giac(r'\lceil x \rceil', 'ceil(x)');
    giac(r'\overline{1+i}', 'conj(1+i)');
    giac(r'\arg(1+i)', 'arg(1+i)');
    giac(r'\mathrm{Re}(z)', 're(z)');
    giac(r'30\%', '(30)/100');
    giac('1{,}5', '1.5');
    giac(r'\sum_{i=1}^{3}i', 'sum(ii,ii,1,3)');
    // Sans parenthèse, ce sont bien des lettres.
    giac('d e t', 'd*e*t');
  });

  group('matrices : déterminant et transposée', () {
    const m = r'\begin{pmatrix}1&2\\3&4\end{pmatrix}';
    giac('\\det$m', 'det([[1,2],[3,4]])', TypeExpression.calcul);
    giac(
      r'\begin{vmatrix}1&2\\3&4\end{vmatrix}',
      'det([[1,2],[3,4]])',
      TypeExpression.calcul,
    );
    giac('\\left|$m\\right|', 'det([[1,2],[3,4]])');
    giac('$m^T', 'transpose([[1,2],[3,4]])', TypeExpression.matrice);
    giac('$m^{T}', 'transpose([[1,2],[3,4]])', TypeExpression.matrice);
  });

  group('limites à droite et à gauche', () {
    giac(r'\lim_{x\to0^+}\frac{1}{x}', 'limit((1)/(x),x,0,1)');
    giac(r'\lim_{x\to0^{-}}\frac{1}{x}', 'limit((1)/(x),x,0,-1)');
    giac(r'\lim_{x\to0+}\frac{1}{x}', 'limit((1)/(x),x,0,1)');
    giac(r'\lim_{x\to1}x', 'limit(x,x,1)');
  });

  group('inéquations', () {
    giac('x>2', 'solve(x>2,x)', TypeExpression.equation);
    giac(r'2x+1\geq3', 'solve(2*x+1>=3,x)', TypeExpression.equation);
    giac(r'x\leq1', 'solve(x<=1,x)', TypeExpression.equation);
    giac('2<3', '2<3', TypeExpression.calcul);

    test('elles ne sont pas des courbes', () {
      expect(analyserLatex('x>2').membres, isNull);
    });
  });

  group('refus : jamais de résultat deviné', () {
    for (final latex in [
      // Une seule borne : la perdre rendrait une primitive.
      r'\int_0 x dx',
      // Un nom inconnu n'est pas le produit de ses lettres.
      r'\operatorname{foo}(x)',
      r'\mathrm{Foo}(x)',
      // y n'est pas défini : ce serait 0 sans rien dire.
      r'\frac{dy}{dx}',
      // `u_{n+1}` n'est pas la variable `u_n` plus 1.
      'u_{n+1}=2u_n',

      '',
      '2+',
      r'\frac{1}',
      '(2+3',
      r'\int x',
      r'\unknown{x}',
      r'\lim x',
      '2+3=4=5',
      r'\begin{cases}x=1',
    ]) {
      test('« $latex »', () {
        expect(() => analyserLatex(latex), throwsA(isA<ErreurLatex>()));
      });
    }
  });
}
