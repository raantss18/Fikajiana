import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:test/test.dart';

/// Ce qui est lu et demandé à Giac, puis l'écriture de sa réponse (ADR 0059).
/// Les réponses de Giac copiées ici viennent de Giac compilé pour Linux au
/// commit de l'app (19a710ae) ; les valeurs se vérifient contre SymPy au banc
/// (`tool/banc/references_feuille.py`, problème « supérieur »).
void main() {
  const a = r'\begin{pmatrix}2&1\\1&2\end{pmatrix}';

  group('ce que Giac calcule', () {
    test('DL d’une expression, en 0 ou en a', () {
      expect(
        analyserLatex(r'\text{DL}(e^{x};0;4)').giac,
        'taylor((e)^(x),x=0,4)',
      );
      expect(
        analyserLatex(r'\text{DL}(\cos(x);\pi;3)').giac,
        'taylor(cos(x),x=pi,3)',
      );
      expect(analyserLatex(r'\text{DL}(e^{x};0;4)').demandeResultat, isTrue);
    });

    test('DL d’une fonction définie plus haut', () {
      final f = analyserLatex(
        r'\text{DL}(f;0;3)',
        definitions: {
          'f': const DefinitionFonction(variable: 'x', corps: 'exp(x)'),
        },
      );
      expect(f.giac, 'taylor((exp(x)),x=0,3)');
    });

    test('DL refusés : ordre hors de 1 à 12, deux variables', () {
      expect(
        () => analyserLatex(r'\text{DL}(x;0;20)'),
        throwsA(isA<ErreurLatex>()),
      );
      expect(
        () => analyserLatex(r'\text{DL}(xy;0;2)'),
        throwsA(isA<ErreurLatex>()),
      );
      expect(
        () => analyserLatex(r'\text{DL}(e^{x};0)'),
        throwsA(isA<ErreurLatex>()),
      );
    });

    test('Laplace et son inverse', () {
      expect(
        analyserLatex(r'\text{laplace}(t^{2})').giac,
        'laplace((t)^(2),t,s)',
      );
      expect(
        analyserLatex(r'\text{invlaplace}(\frac{1}{s-2})').giac,
        'invlaplace((1)/(s-2),s,t)',
      );
      expect(
        () => analyserLatex(r'\text{laplace}(s^{2})'),
        throwsA(isA<ErreurLatex>()),
      );
    });

    test('matrices, avec ou sans parenthèses', () {
      expect(analyserLatex('\\text{rang}($a)').giac, 'rank([[2,1],[1,2]])');
      expect(analyserLatex('\\text{rang}$a').giac, 'rank([[2,1],[1,2]])');
      expect(analyserLatex('\\text{tr}($a)').giac, 'trace([[2,1],[1,2]])');
      expect(analyserLatex('\\text{noyau}($a)').giac, 'ker([[2,1],[1,2]])');
      expect(
        analyserLatex('\\text{valeurspropres}($a)').giac,
        '[eigenvals([[2,1],[1,2]])]',
      );
      expect(
        analyserLatex('\\text{polycar}($a)').giac,
        'charpoly([[2,1],[1,2]],x)',
      );
      expect(
        analyserLatex('\\text{diagonaliser}($a)').giac,
        '[[jordan([[2,1],[1,2]])],[jordan([[2,1],[1,2]])][1]'
        '==diag(diag([jordan([[2,1],[1,2]])][1]))]',
      );
    });

    test('une matrice déclarée sur la feuille', () {
      expect(
        analyserLatex(
          r'\text{rang}\left(A\right)',
          valeurs: {'A': '[[1,2],[2,4]]'},
        ).giac,
        'rank(([[1,2],[2,4]]))',
      );
    });

    test('pas une matrice : refusé', () {
      expect(
        () => analyserLatex(r'\text{rang}(5)'),
        throwsA(isA<ErreurLatex>()),
      );
    });

    test('au clavier', () {
      expect(
        lireSaisie('DL(exp(x);0;4)').latex,
        r'\text{DL}\left(\exp\left(x\right);0;4\right)',
      );
      expect(
        analyserLatex(lireSaisie('DL(exp(x);0;4)').latex!).giac,
        'taylor(exp(x),x=0,4)',
      );
      expect(
        analyserLatex(
          lireSaisie('diagonaliser(A)').latex!,
          valeurs: {'A': '[[2,1],[1,2]]'},
        ).giac,
        startsWith('[[jordan('),
      );
    });

    test('trace reste « tracer » : seul tr(A) est la trace', () {
      expect(superieurDemande(r'\text{trace}(f)'), isNull);
      expect(superieurDemande(r'\text{tr}(A)'), Superieur.trace);
    });
  });

  group('écriture de la réponse de Giac', () {
    String? ecrire(Superieur c, String r) =>
        ecrireSuperieur(c, r, francais: true);

    test('le reste du DL s’écrit o(xⁿ)', () {
      expect(
        ecrire(
          Superieur.taylor,
          r'1+x+\frac{1}{2} \cdot x^{2}+x^{3} \mathrm{order\_size}\left(x\right)',
        ),
        r'1+x+\frac{1}{2} \cdot x^{2}+o\left(x^{2}\right)',
      );
      expect(
        ecrire(
          Superieur.taylor,
          r'-1+\frac{1}{2} \cdot \left(x-\pi \right)^{2}+\left(x-\pi \right)^{4}'
          r' \mathrm{order\_size}\left(x-\pi \right)',
        ),
        [
          r'-1+\frac{1}{2} \cdot \left(x-\pi \right)^{2}',
          r'+o\left(\left(x-\pi \right)^{3}\right)',
        ].join(),
      );
      expect(
        ecrire(Superieur.taylor, r'1+x^{2} \mathrm{order\_size}\left(x\right)'),
        r'1+o\left(x\right)',
      );
    });

    test('noyau : {0} ou une base en colonnes', () {
      expect(ecrire(Superieur.noyau, '[]'), r'\{0\}');
      expect(
        ecrire(
          Superieur.noyau,
          r'\left(\begin{array}{ccc} \mathrm{-1} & 2 & \mathrm{-1} '
          r'\end{array}\right) ',
        ),
        r'\mathrm{Vect}\left(\begin{pmatrix}-1\\2\\-1\end{pmatrix}\right)',
      );
    });

    test('valeurs propres : sans répétition', () {
      expect(
        ecrire(Superieur.valeursPropres, r'[3,\mathrm{-1},3]'),
        r'\left\{3\,;\,-1\right\}',
      );
    });

    test('diagonaliser : P et D, ou P et J et la raison', () {
      const p =
          r'\left(\begin{array}{cc} 1 & \mathrm{-1} \\ 1 & 1 '
          r'\end{array}\right) ';
      const d = r'\left(\begin{array}{cc} 3 & 0 \\ 0 & 1 \end{array}\right) ';
      expect(
        ecrire(Superieur.diagonaliser, '[[$p,$d],\\mbox{true}]'),
        [
          r'P=\left(\begin{array}{cc} 1 & -1 \\ 1 & 1 \end{array}\right),',
          r'\;D=\left(\begin{array}{cc} 3 & 0 \\ 0 & 1 \end{array}\right)',
        ].join(),
      );
      expect(
        ecrireSuperieur(
          Superieur.diagonaliser,
          '[[$p,$d],\\mbox{false}]',
          francais: false,
        ),
        endsWith(r'\;(\text{not diagonalizable})'),
      );
    });

    test('les autres s’affichent tels quels', () {
      expect(ecrire(Superieur.rang, '2'), isNull);
      expect(ecrire(Superieur.laplace, r'\frac{2}{s^{3}}'), isNull);
    });
  });
}
