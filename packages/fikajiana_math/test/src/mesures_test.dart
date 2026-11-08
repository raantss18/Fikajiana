import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:test/test.dart';

// Références calculées par SymPy 1.14 (`sympy.geometry.Polygon`, `acos` du
// produit scalaire normé), recopiées ici : voir docs/adr/0046.
double valeur(String giac) => compilerFonction(giac, variable: '_')(0);

void main() {
  const points = {
    'A': (0.0, 0.0),
    'B': (4.0, 0.0),
    'C': (1.0, 3.0),
    'D': (0.5, 2.5),
    'E': (-2.0, 1.0),
  };
  Analyse lire(String latex) => analyserLatex(latex, points: points);

  group('angle en B, en radians pour l’évaluateur', () {
    for (final ecrit in [
      'angle(A;B;C)=',
      r'\text{angle}\left(A;B;C\right)=',
      r'\widehat{ABC}=',
      r'\angle ABC=',
      'angle(ABC)=',
    ]) {
      test('$ecrit vaut π/4 (SymPy)', () {
        final a = lire(ecrit);
        expect(a.demandeResultat, isTrue);
        expect(valeur(a.giac), closeTo(0.785398163397448, 1e-12));
      });
    }
    test('angle(B;A;C) = acos(√10/10) ≈ 1,24904577239825 (SymPy)', () {
      expect(
        valeur(lire('angle(B;A;C)=').giac),
        closeTo(1.24904577239825, 1e-12),
      );
    });
    test('un angle obtus : acos(−2√5/5) ≈ 2,67794504458899 (SymPy)', () {
      expect(
        valeur(lire('angle(E;A;B)=').giac),
        closeTo(2.67794504458899, 1e-12),
      );
    });
    test('passe à Giac sa forme exacte, sans décimale', () {
      expect(lire('angle(A;B;D)=').giac, isNot(contains('.')));
      expect(lire('angle(A;B;D)=').giac, contains('(1/2)'));
    });
    test('un côté nul ne donne rien', () {
      expect(() => lire('angle(A;A;C)='), throwsA(isA<ErreurLatex>()));
    });
    test('un point inconnu ne se devine pas', () {
      expect(() => lire('angle(A;B;Z)='), throwsA(isA<ErreurLatex>()));
    });
  });

  group('aire', () {
    test('aire(ABC) = 6 (SymPy)', () {
      expect(valeur(lire('aire(ABC)=').giac), closeTo(6, 1e-12));
      expect(valeur(lire(r'\mathrm{aire}(A;B;C)=').giac), closeTo(6, 1e-12));
    });
    test('aire(ABCD) = 13/2 (SymPy), sommets dans l’autre sens', () {
      expect(valeur(lire('aire(ABCD)=').giac), closeTo(6.5, 1e-12));
      expect(valeur(lire('aire(DCBA)=').giac), closeTo(6.5, 1e-12));
    });
    test('deux sommets ne font pas une aire', () {
      expect(() => lire('aire(AB)='), throwsA(isA<ErreurLatex>()));
    });
  });

  group('périmètre', () {
    test('périmètre(ABC) = 4+3√2+√10 ≈ 11,4049183472877 (SymPy)', () {
      for (final ecrit in [
        'périmètre(ABC)=',
        'perimetre(A;B;C)=',
        r'\text{périmètre}\left(ABC\right)=',
      ]) {
        expect(valeur(lire(ecrit).giac), closeTo(11.4049183472877, 1e-12));
      }
    });
    test('périmètre(ABCD) = 4+7√2/2+√26/2 ≈ 11,4992572251022 (SymPy)', () {
      final a = lire('périmètre(ABCD)=');
      expect(valeur(a.giac), closeTo(11.4992572251022, 1e-12));
      expect(a.giac, isNot(contains('.')));
    });
  });

  test('se tape au clavier tel quel', () {
    expect(lireSaisie('angle(A;B;C)=').latex, 'angle(A;B;C)=');
    expect(lireSaisie('aire(ABC)=').latex, 'aire(ABC)=');
    expect(lireSaisie('périmètre(ABC)=').latex, 'périmètre(ABC)=');
  });
}
