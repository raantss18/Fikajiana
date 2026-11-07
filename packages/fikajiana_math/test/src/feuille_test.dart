import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:test/test.dart';

void main() {
  final f = analyserLatex('f(x)=x+5');
  final defs = {f.nomFonction!: f.definition!};
  Analyse lire(String latex) => analyserLatex(latex, definitions: defs);

  group('une fonction définie plus haut', () {
    test('f(x)=x+5 se retient', () {
      expect(f.nomFonction, 'f');
      expect(f.definition!.corps, 'x+5');
    });
    test("f'(x) est sa dérivée, et donne une réponse sans =", () {
      for (final ecrit in [
        "f'(x)",
        r'f^{\prime}(x)',
        r'f ^ { \prime } ( x )',
      ]) {
        final a = lire(ecrit);
        expect(a.giac, 'diff(x+5,x)', reason: ecrit);
        expect(a.demandeResultat, isTrue);
      }
    });
    test("f''(x) dérive deux fois", () {
      expect(lire("f''(x)").giac, 'diff(x+5,x,2)');
      expect(lire(r'f^{\prime\prime}(x)').giac, 'diff(x+5,x,2)');
    });
    test("f'(2) dérive puis remplace", () {
      expect(lire("f'(2)").giac, 'subst(diff(x+5,x),x=2)');
    });
    test('f(2) vaut 7', () {
      final a = lire('f(2)');
      expect(compilerFonction(a.giac)(0), 7);
      expect(a.demandeResultat, isTrue);
    });
    test('f(x)=0 est une équation en x', () {
      final a = lire('f(x)=0');
      expect(a.type, TypeExpression.equation);
      expect(a.inconnues, ['x']);
      expect(a.giac, 'solve((x+5)=0,x)');
    });
    test('f(x)=3 aussi, mais f(x)=2x la redéfinit', () {
      expect(lire('f(x)=3').type, TypeExpression.equation);
      final a = lire('f(x)=2x');
      expect(a.type, TypeExpression.fonction);
      expect(a.definition!.corps, '2*x');
    });
    test("f'(x)=0 est une équation", () {
      expect(lire("f'(x)=0").type, TypeExpression.equation);
    });
    test('sans définition, f(x)=0 reste une fonction à tracer', () {
      expect(analyserLatex('f(x)=0').type, TypeExpression.fonction);
    });
    test('une autre lettre se définit aussi', () {
      final k = analyserLatex('k(x)=x^{2}');
      final d = {k.nomFonction!: k.definition!};
      final v = analyserLatex('k(3)', definitions: d);
      expect(compilerFonction(v.giac)(0), 9);
    });
    test('x(x+1) reste un produit, même avec f définie', () {
      expect(lire('x(x+1)').giac, 'x*(x+1)');
    });
  });

  group('le déterminant', () {
    const matrice = r'\begin{pmatrix}1&5\\-1&8\end{pmatrix}';
    test('écrit de toutes les façons', () {
      const attendu = 'det([[1,5],[(-1),8]])';
      for (final ecrit in [
        '\\det $matrice',
        'det $matrice',
        'd e t $matrice',
        '\\det\\left($matrice\\right)',
        r'\begin{vmatrix}1&5\\-1&8\end{vmatrix}',
        r'\mathrm{det}\left(\begin{array}{cc}1&5\\-1&8\end{array}\right)',
      ]) {
        final a = analyserLatex(ecrit);
        expect(
          a.giac.replaceAll(' ', ''),
          contains(attendu.substring(4, 20)),
          reason: ecrit,
        );
        expect(a.giac, startsWith('det('), reason: ecrit);
        expect(a.demandeResultat, isTrue, reason: ecrit);
      }
    });
  });

  group('un point ou un vecteur', () {
    void point(String ecrit, String nom, double x, double y) {
      test(ecrit, () {
        final o = lireObjet(ecrit);
        expect(o, isA<PointLu>());
        expect((o!.nom, o.x, o.y), (nom, x, y));
      });
    }

    void vecteur(String ecrit, String nom, double x, double y) {
      test(ecrit, () {
        final o = lireObjet(ecrit);
        expect(o, isA<VecteurLu>());
        expect((o!.nom, o.x, o.y), (nom, x, y));
      });
    }

    point('A(1;2)', 'A', 1, 2);
    point('A ( 1 ; 2 )', 'A', 1, 2);
    point(r'A \left( 1 ; 2 \right)', 'A', 1, 2);
    point('A(1,2)', 'A', 1, 2);
    point('A=(1;2)', 'A', 1, 2);
    point('A(1|2)', 'A', 1, 2);
    point('A(1,5;2)', 'A', 1.5, 2);
    point(r'B(\frac{1}{2};-3)', 'B', 0.5, -3);
    vecteur(r'\overrightarrow{AB}\begin{pmatrix}1\\3\end{pmatrix}', 'AB', 1, 3);
    vecteur(
      r'\overrightarrow { A B } \left( \begin{array} { c } 1 \\ 3 \end{array} \right)',
      'AB',
      1,
      3,
    );
    vecteur(r'\vec{u}(1;3)', 'u', 1, 3);
    vecteur('AB(1;3)', 'AB', 1, 3);
    vecteur('u(1;3)', 'u', 1, 3);
    test('ce n’est ni une fonction ni un produit', () {
      expect(lireObjet('f(x)'), isNull);
      expect(lireObjet('A(x;2)'), isNull);
      expect(lireObjet('2(1+3)'), isNull);
      expect(lireObjet('x(1,5)'), isNull);
    });
    test('se tape au clavier', () {
      expect(lireSaisie('A(1;2)').latex, 'A(1;2)');
      expect(lireSaisie('AB(1;3)').latex, 'AB(1;3)');
    });
  });
}
