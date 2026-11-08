import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:test/test.dart';

// Feuille d'Antsa (Pad 7, 15 h 14) : `y' − 3y = cos(x)`, que le modèle lit
// `y^{1}-3y=\cos(x)` ; l'app le proposait comme une courbe à tracer.

void main() {
  test("y' − 3y = cos(x), lu y^{1} : desolve", () {
    final a = analyserLatex(r'y ^ { 1 } - 3 y = \cos \left( x \right)');
    expect(a.demandeResultat, isTrue);
    expect(a.giac, 'y(x)=desolve((diff(y(x),x)-3*y(x))=(cos(x)),y(x))');
  });

  test("y'(t) = t ; y'' + y = 0 refusé (Giac tombe)", () {
    expect(
      analyserLatex("y'(t)=t").giac,
      'y(t)=desolve((diff(y(t),t))=(t),y(t))',
    );
    expect(() => analyserLatex("y''+y=0"), throwsA(isA<ErreurLatex>()));
  });

  test('sans dérivée, rien ne change', () {
    expect(analyserLatex('y=2x+1').type, TypeExpression.fonction);
    expect(analyserLatex('y^{12}=3').giac, isNot(contains('desolve')));
    expect(analyserLatex('y^{2}=4').giac, isNot(contains('desolve')));
    expect(analyserLatex("f'(x)=").giac, isNot(contains('desolve')));
  });
}
