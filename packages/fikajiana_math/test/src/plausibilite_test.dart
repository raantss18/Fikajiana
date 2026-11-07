import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:test/test.dart';

void main() {
  group('plausibilité', () {
    test('une écriture ordinaire n’étonne pas', () {
      for (final l in [
        'x^{2}+3x-5=0',
        'f(x)=e^{x}+2',
        r'\frac{1}{3}',
        '2+3=',
      ]) {
        expect(plausibilite(l), 0, reason: l);
      }
    });
    test('deux lignes dans une matrice sont suspectes', () {
      expect(
        plausibilite(r'\begin{matrix}g(x)=3x\\g(x)=\end{matrix}'),
        lessThan(-10),
      );
    });
    test('ce qui ne se lit pas est le plus suspect', () {
      expect(plausibilite(r'\unknown{x}'), lessThanOrEqualTo(-100));
    });
    test('une lettre rare coûte, un mot coûte plus', () {
      expect(plausibilite('q+1'), lessThan(0));
      expect(plausibilite('hello'), lessThan(plausibilite('q+1')));
    });
    test('une fonction connue rassure', () {
      expect(plausibilite('q(2)', fonctions: {'q'}), 0);
    });
    test('les lectures relevées sur le Pad 7 passent une fois redressées', () {
      for (final l in ['1/4(x)=e^x+2', 'f^1(x)=', 'g^((x))=0']) {
        expect(plausibilite(l, fonctions: {'f', 'g'}), 0, reason: l);
      }
    });
  });

  group('choisir une lecture', () {
    test('la première reste si rien ne la dépasse nettement', () {
      expect(choisirLecture(['x+1', 'x+l']), 'x+1');
      expect(choisirLecture(['x^{2}', 'x^{3}']), 'x^{2}');
    });
    test('une lecture sensée passe devant une lecture impossible', () {
      expect(
        choisirLecture([
          r'\begin{matrix}g(x)=3x\\g(x)=\end{matrix}',
          'g(x)=3x',
        ]),
        'g(x)=3x',
      );
      expect(choisirLecture(['x^{', 'x^{2}']), 'x^{2}');
    });
  });
}
