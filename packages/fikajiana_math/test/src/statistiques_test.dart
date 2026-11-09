import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:test/test.dart';

/// Les valeurs se vérifient contre SymPy au banc (`tool/banc/
/// references_feuille.py`, problème « statistiques à deux variables ») ;
/// ici, ce qui est lu et la forme de ce qui est demandé à Giac.
void main() {
  group('ajustements', () {
    for (final (ecrit, inconnues) in [
      (r'\text{ajustement}([1;2;3;4];[2;4;5;8])', ['a', 'b', 'r']),
      (
        r'\text{ajustement}\left(\left[1;2;3\right];\left[2;4;7\right]\right)',
        ['a', 'b', 'r'],
      ),
      (r'\text{ajustement}([1;2;3];[2;4;7];exp)', ['a', 'b']),
      (r'\text{ajustement}([1;2;3];[2;4;7];ln)', ['a', 'b']),
      (r'\text{ajustement}([1;2;3];[2;4;7];puissance)', ['a', 'b']),
      (r'\text{ajustement}([1;2;3;4];[1;4;9;17];2)', ['a', 'b', 'c']),
      (r'\text{régression}([1;2;3];[2;4;7])', ['a', 'b', 'r']),
    ]) {
      test(ecrit, () {
        final a = analyserLatex(ecrit);
        expect(a.type, TypeExpression.systeme);
        expect(a.inconnues, inconnues);
        expect(a.giac, startsWith('['));
      });
    }

    test('droite : la pente des moindres carrés, terme à terme', () {
      final a = analyserLatex(r'\text{ajustement}([1;2];[3;5])');
      // n Σxy − Σx Σy sur n Σx² − (Σx)².
      expect(a.giac, contains('(2*((1)*(3)+(2)*(5))-((1)+(2))*((3)+(5)))'));
    });

    test('listes de longueurs différentes ou modèle inconnu : refusés', () {
      expect(
        () => analyserLatex(r'\text{ajustement}([1;2;3];[2;4])'),
        throwsA(isA<ErreurLatex>()),
      );
      expect(
        () => analyserLatex(r'\text{ajustement}([1;2];[2;4];sinus)'),
        throwsA(isA<ErreurLatex>()),
      );
    });
  });

  group('corrélation, covariance', () {
    test('corrélation : un nombre approché ; covariance : population', () {
      final r = analyserLatex(r'\text{corrélation}([1;2;3];[2;4;7])=');
      expect(r.type, TypeExpression.calcul);
      expect(r.giac, startsWith('evalf('));
      final c = analyserLatex(r'\text{covariance}([1;2;3];[2;4;7])=');
      expect(
        c.giac,
        '((1)*(2)+(2)*(4)+(3)*(7))/3-'
        '(((1)+(2)+(3))/3)*(((2)+(4)+(7))/3)',
      );
    });
  });

  group('quartiles, définition du lycée', () {
    test('rangs ⌈n/4⌉ et ⌈3n/4⌉, médiane au milieu', () {
      final a = analyserLatex(r'\text{quartiles}(3;1;7;5;9;2)');
      expect(a.inconnues, ['Q_1', 'M_e', 'Q_3']);
      expect(a.giac, contains('[ceil(6/4)-1]'));
      expect(a.giac, contains('[ceil(3*6/4)-1]'));
      // n pair : la moyenne des 3ᵉ et 4ᵉ valeurs.
      expect(a.giac, contains('[3-1]'));
      expect(a.giac, contains('[4-1]'));
    });

    test('une liste entre crochets aussi', () {
      expect(analyserLatex(r'\text{quartiles}([1;2;3;4;5])').inconnues, [
        'Q_1',
        'M_e',
        'Q_3',
      ]);
    });
  });

  group('au clavier', () {
    for (final (tape, inconnues) in [
      ('ajustement([1;2;3;4];[2;4;5;8])', ['a', 'b', 'r']),
      ('ajustement([1;2;3];[2;4;7];exp)', ['a', 'b']),
      ('ajustement([0,5;1;1,5];[2;3;5])', ['a', 'b', 'r']),
      ('quartiles(3;1;7;5;9;2)', ['Q_1', 'M_e', 'Q_3']),
    ]) {
      test(tape, () {
        final latex = lireSaisie(tape).latex;
        expect(latex, isNotNull);
        expect(analyserLatex(latex!).inconnues, inconnues);
      });
    }

    test('une décimale à virgule reste un nombre', () {
      final latex = lireSaisie('ajustement([0,5;1;1,5];[2;3;5])').latex!;
      expect(analyserLatex(latex).giac, contains('(0.5)'));
    });
  });
}
