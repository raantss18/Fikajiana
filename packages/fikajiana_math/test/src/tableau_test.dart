import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:test/test.dart';

/// Les valeurs se vérifient contre SymPy au banc (problème « tableau de
/// valeurs ») ; ici, les x calculés et ce qui est demandé à Giac.
void main() {
  final f = analyserLatex('f(x)=x^{2}-1');
  final definitions = {f.nomFonction!: f.definition!};

  test('une fonction définie : x de 0 à 3, f(x) par sa définition', () {
    final a = analyserLatex(
      r'\text{tableau}(f;0;3;1)',
      definitions: definitions,
    );
    expect(a.type, TypeExpression.calcul);
    expect(a.demandeResultat, isTrue);
    expect(a.giac, startsWith('[[0,1,2,3],['));
  });

  test('une expression en x, pas décimal : x exacts (1/2)', () {
    final a = analyserLatex(r'\text{tableau}(x^{2}-1;-1;1;0{,}5)');
    expect(a.giac, startsWith('[[-1,(-1/2),0,(1/2),1],'));
    expect(a.giac, contains('subst((x)^(2)-1,x=(1/2))'));
  });

  test('sans pas : 1 ; avec =', () {
    final a = analyserLatex(r'tableau(\frac{1}{x};1;3)=');
    expect(a.giac, startsWith('[[1,2,3],'));
  });

  test('trop de colonnes, pas nul, fin avant début : refusés', () {
    for (final ecrit in [
      r'\text{tableau}(x;0;100;1)',
      r'\text{tableau}(x;0;3;0)',
      r'\text{tableau}(x;3;0;1)',
      r'\text{tableau}(x;a;3;1)',
    ]) {
      expect(
        () => analyserLatex(ecrit),
        throwsA(isA<ErreurLatex>()),
        reason: ecrit,
      );
    }
  });

  test('au clavier', () {
    final latex = lireSaisie('tableau(x^2-1;-1;1;0,5)').latex!;
    expect(analyserLatex(latex).giac, startsWith('[[-1,(-1/2),0,(1/2),1],'));
    expect(lireSaisie('tableau(f;0;3;1)').latex, isNotNull);
  });
}
