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
    expect(latexLisible(r'y(x)=(\mathrm{c\_0} e^{-x})'), 'y(x)=(C_{0} e^{-x})');
  });
}
