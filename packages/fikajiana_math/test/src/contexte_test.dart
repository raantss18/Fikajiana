import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:test/test.dart';

double valeur(String giac) => compilerFonction(giac, variable: '_')(0);

void main() {
  const points = {'A': (1.0, 2.0), 'B': (5.0, -4.0)};
  Analyse lire(String latex) => analyserLatex(latex, points: points);

  group('entre deux points de la feuille', () {
    test('le vecteur AB se calcule', () {
      final a = lire(r'\overrightarrow{AB}');
      expect(a.giac, '[4,-6]');
      expect(a.demandeResultat, isTrue);
    });
    test('sa norme, selon la référence √(16+36)', () {
      final a = lire(r'\|\overrightarrow{AB}\|');
      expect(valeur(a.giac), closeTo(7.211102550927978, 1e-9));
      expect(a.demandeResultat, isTrue);
    });
    test('la distance AB', () {
      final a = lire('AB');
      expect(valeur(a.giac), closeTo(7.211102550927978, 1e-9));
      expect(a.demandeResultat, isTrue);
    });
    test('un point inconnu ne se devine pas', () {
      expect(() => lire(r'\overrightarrow{AC}'), throwsA(isA<ErreurLatex>()));
    });
    test('sans points, AB reste un produit', () {
      expect(analyserLatex('AB').giac, 'A*B');
    });
    test('un vecteur déclaré', () {
      final a = analyserLatex(
        r'\|\vec{u}\|',
        vecteurs: const {'u': (3.0, 4.0)},
      );
      expect(valeur(a.giac), 5);
    });
  });

  group('a=2', () {
    test('définit a', () {
      final a = analyserLatex('a=2');
      expect(a.nomValeur, 'a');
      expect(a.giac, '2');
    });
    test('sert aux lignes suivantes', () {
      final a = analyserLatex('a+1', valeurs: const {'a': '2'});
      expect(valeur(a.giac), 3);
      final f = analyserLatex('f(x)=a x', valeurs: const {'a': '2'});
      expect(f.corps, '(2)*x');
    });
    test('les inconnues restent des équations', () {
      for (final l in ['x=2', 'y=2', 'z=2', 't=2', 'r=2']) {
        expect(analyserLatex(l).nomValeur, isNull, reason: l);
        expect(analyserLatex(l).type, TypeExpression.equation, reason: l);
      }
    });
    test('a=b reste une équation', () {
      expect(analyserLatex('a=b').nomValeur, isNull);
    });
  });
}
