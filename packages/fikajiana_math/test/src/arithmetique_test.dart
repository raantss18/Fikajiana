import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:test/test.dart';

/// Les valeurs se vérifient contre SymPy au banc sur l'appareil
/// (`tool/banc/references_feuille.py`, problème « arithmétique ») ; ici, ce
/// qui est lu et ce qui est demandé à Giac.
void main() {
  group('division euclidienne', () {
    test('division(17;5) : q et r, reste positif', () {
      final a = analyserLatex(r'\text{division}\left(17;5\right)');
      expect(a.type, TypeExpression.systeme);
      expect(a.inconnues, ['q', 'r']);
      expect(a.giac, '[[floor((17)/(5)),(17)-(5)*floor((17)/(5))]]');
    });

    test('écrite à la main sans police, avec =, ou avec une virgule', () {
      expect(analyserLatex('division(17;5)=').inconnues, ['q', 'r']);
      expect(analyserLatex('division(17,5)').inconnues, ['q', 'r']);
      expect(() => analyserLatex('division(17)'), throwsA(isA<ErreurLatex>()));
    });

    test('quotient et reste seuls', () {
      expect(
        analyserLatex(r'\operatorname{quotient}(17;5)').giac,
        'iquo(17,5)',
      );
      expect(analyserLatex(r'\text{reste}(17;5)').giac, 'irem(17,5)');
      expect(analyserLatex(r'\text{reste}(17;5)').demandeResultat, isTrue);
    });
  });

  test('Bézout : u, v et le pgcd', () {
    final a = analyserLatex(r'\text{bezout}(12;18)');
    expect(a.type, TypeExpression.systeme);
    expect(a.inconnues, ['u', 'v', 'd']);
    expect(a.giac, '[iegcd(12,18)]');
  });

  group('congruences', () {
    for (final ecrit in [
      r'17\equiv2[5]',
      r'17 \equiv 2 \pmod{5}',
      r'17\equiv 2\left(\bmod 5\right)',
      r'17\equiv 2 \mod 5',
    ]) {
      test(ecrit, () {
        expect(analyserLatex(ecrit).giac, 'irem((17)-(2),5)==0');
      });
    }

    test('une inconnue : refusée (pas encore résolue)', () {
      expect(() => analyserLatex(r'x\equiv 2[5]'), throwsA(isA<ErreurLatex>()));
    });
  });

  group('arrangements', () {
    test('A_5^2 = perm(5,2) ; une matrice A_1 reste A_1', () {
      expect(analyserLatex('A_{5}^{2}=').giac, 'perm(5,2)');
      expect(analyserLatex('A_5^2+1=').giac, 'perm(5,2)+1');
      expect(analyserLatex('A_{1}+B').giac, 'A_1+B');
    });
  });

  group('au clavier', () {
    for (final (tape, giac) in [
      ('division(17;5)', '[[floor((17)/(5)),(17)-(5)*floor((17)/(5))]]'),
      ('quotient(17;5)', 'iquo(17,5)'),
      ('reste(17;5)', 'irem(17,5)'),
      ('bezout(12;18)', '[iegcd(12,18)]'),
      ('17≡2[5]', 'irem((17)-(2),5)==0'),
      ('17 equiv 2 mod 5', 'irem((17)-(2),5)==0'),
      ('2^10 ≡ 1 (mod 11)', 'irem(((2)^(10))-(1),11)==0'),
    ]) {
      test(tape, () {
        final latex = lireSaisie(tape).latex;
        expect(latex, isNotNull);
        expect(analyserLatex(latex!).giac, giac);
      });
    }
  });
}
