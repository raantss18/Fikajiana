import 'package:fikajiana/moteur/giac.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('h(1) pour h(x)=xe^{-x} : 1/e, plus « inv(e¹) »', () {
    final r = ReponseGiac.analyser(
      'exp(-1)\x1f\\mathrm{inv}\\left(e^{1}\\right)\x1f0.367879441171',
    );
    expect(r.latex, r'\frac{1}{e}');
  });

  test('e^{1} s’écrit e, e^{12} reste', () {
    expect(latexLisible(r'-\frac{2}{e^{1}}+1'), r'-\frac{2}{e}+1');
    expect(latexLisible('e^{12}'), 'e^{12}');
  });

  test('la constante de desolve s’écrit C_{0}', () {
    expect(latexLisible(r'y(x)=(\mathrm{c\_0} e^{-x})'), 'y=C_{0} e^{-x}');
  });

  test('2*i de csolve s’écrit 2i, et * devient un point (ADR 0058)', () {
    expect(latexLisible(r'\{1+2*i,1-2*i\}'), r'\{1+2i,1-2i\}');
    expect(latexLisible(r'\frac{1-3*i}{2}'), r'\frac{1-3i}{2}');
    expect(
      latexLisible(r'\frac{(1+i)}{2} \cdot \sqrt{2}'),
      r'\frac{(1+i)}{2} \cdot \sqrt{2}',
    );
    expect(latexLisible('a*b'), r'a\cdot b');
  });
}
