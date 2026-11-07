import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:test/test.dart';

/// Demande d'Antsa : `A = (…)` déclarée sur la feuille, puis `det(A)`,
/// `A^{-1}` ou `AX = B` sur les lignes suivantes.
void main() {
  final a = analyserLatex(r'A=\begin{pmatrix}1&2\\3&4\end{pmatrix}');
  final b = analyserLatex(r'B=\begin{pmatrix}5\\6\end{pmatrix}');
  final valeurs = {a.nomValeur!: a.giac, b.nomValeur!: b.giac};

  test('une matrice se déclare comme une valeur', () {
    expect(a.nomValeur, 'A');
    expect(a.giac, '[[1,2],[3,4]]');
    expect(b.giac, '[[5],[6]]');
  });

  test('det(A), A^{-1}, AB se calculent avec A de la feuille', () {
    expect(
      analyserLatex(r'\det(A)', valeurs: valeurs).giac,
      'det(([[1,2],[3,4]]))',
    );
    expect(
      analyserLatex('A^{-1}', valeurs: valeurs).giac,
      '(([[1,2],[3,4]]))^((-1))',
    );
    expect(
      analyserLatex('AB=', valeurs: valeurs).giac,
      '([[1,2],[3,4]])*([[5],[6]])',
    );
  });

  test('AX=B : X = A⁻¹B, pas un solve impossible', () {
    for (final ecrit in ['AX=B', r'A\cdot X=B', r'A\times X=B']) {
      final r = analyserLatex(ecrit, valeurs: valeurs);
      expect(r.inconnueMatrice, 'X', reason: ecrit);
      expect(r.giac, 'inv([[1,2],[3,4]])*(([[5],[6]]))', reason: ecrit);
    }
  });

  test('XA=B : X = BA⁻¹', () {
    final r = analyserLatex('XA=C', valeurs: {...valeurs, 'C': '[[1,0]]'});
    expect(r.inconnueMatrice, 'X');
    expect(r.giac, '(([[1,0]]))*inv([[1,2],[3,4]])');
  });

  test('AX=B avec un vecteur B déclaré par ses coordonnées', () {
    final r = analyserLatex(
      'AX=V',
      valeurs: valeurs,
      vecteurs: const {'V': (5, 6)},
    );
    expect(r.giac, 'inv([[1,2],[3,4]])*([[5],[6]])');
  });

  test('une équation ordinaire reste une équation', () {
    final r = analyserLatex('2x=4');
    expect(r.inconnueMatrice, isNull);
    expect(r.type, TypeExpression.equation);
  });

  test('au clavier : A=[1,2;3,4], [[1,2],[3,4]], B=[5;6]', () {
    expect(
      lireSaisie('A=[1,2;3,4]').latex,
      r'A=\begin{pmatrix}1&2\\3&4\end{pmatrix}',
    );
    expect(
      lireSaisie('A=[[1,2],[3,4]]').latex,
      r'A=\begin{pmatrix}1&2\\3&4\end{pmatrix}',
    );
    expect(lireSaisie('B=[5;6]').latex, r'B=\begin{pmatrix}5\\6\end{pmatrix}');
    expect(analyserLatex(lireSaisie('A=[1,2;3,4]').latex!).nomValeur, 'A');
    expect(lireSaisie('[3]').latex, isNot(contains('pmatrix')));
  });
}
