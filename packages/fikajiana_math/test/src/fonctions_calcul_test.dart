import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:test/test.dart';

void main() {
  group('écrit à la main ou en LaTeX', () {
    void donne(String latex, String giac) {
      test(latex, () {
        final a = analyserLatex(latex);
        expect(a.giac, giac);
        expect(a.demandeResultat, isTrue);
      });
    }

    donne(
      r'\operatorname{développer}\left((x+1)^{2}\right)',
      'expand(((x+1))^(2))',
    );
    donne(r'\mathrm{factoriser}(x^{2}-1)', 'factor((x)^(2)-1)');
    donne('factoriser(x^{2}-1)', 'factor((x)^(2)-1)');
    donne('simplifier(x/x)', 'simplify(x/(x))');
    donne('expand(x(x+1))', 'expand(x*(x+1))');
    donne('decomposer(360)', 'ifactor(360)');
    donne('premier(97)', 'isprime(97)');
    donne('moyenne(2;4;9)', 'mean([2,4,9])');
    donne('moyenne(2,4,9)', 'mean([2,4,9])');
    donne(r'\mathrm{médiane}(3;1;2)', '(sort([3,1,2])[1]+sort([3,1,2])[1])/2');
    donne('mediane(1;2;3;4)', '(sort([1,2,3,4])[1]+sort([1,2,3,4])[2])/2');
    donne('variance(1;2;3;4)', 'variance([1,2,3,4])');
    donne(r'\operatorname{écart-type}(2;4)', 'stddev([2,4])');
    donne('arrondi(3,14159;2)', 'round(3.14159,2)');
    donne('pgcd(12;18)', 'gcd(12,18)');
    donne(
      'discriminant(x^{2}-3x+2)',
      'normal(coeff(((x)^(2)-3*x+2),x,1)^2-4*coeff(((x)^(2)-3*x+2),x,2)'
          '*coeff(((x)^(2)-3*x+2),x,0))',
    );

    test('tangente(f;2) se sert de f, définie plus haut', () {
      final a = analyserLatex(
        'tangente(f;2)',
        definitions: {
          'f': const DefinitionFonction(variable: 'x', corps: 'x^2'),
        },
      );
      expect(a.giac, 'normal(((2)^2)+subst(diff(x^2,x),x=2)*(x-(2)))');
    });

    test('tangente sans f définie : refusée, rien de deviné', () {
      expect(() => analyserLatex('tangente(f;2)'), throwsA(isA<ErreurLatex>()));
    });

    test('tan(x) reste la tangente trigonométrique', () {
      expect(analyserLatex(r'\tan(x)=').giac, 'tan(x)');
    });

    test('exp(x) reste l’exponentielle', () {
      expect(analyserLatex('exp(1)=').giac, 'exp(1)');
    });

    test('le produit scalaire de deux vecteurs', () {
      final a = analyserLatex(
        r'\vec{u}\cdot\vec{v}',
        vecteurs: const {'u': (1, 2), 'v': (3, -4)},
      );
      expect(a.giac, 'dot([1,2],[3,-4])');
    });

    test('une liste de lettres est refusée', () {
      expect(() => analyserLatex('moyenne(a;b)'), throwsA(isA<ErreurLatex>()));
    });
  });

  group('tapé au clavier', () {
    void tape(String texte, String latex) {
      test(texte, () => expect(lireSaisie(texte).latex, latex));
    }

    tape(
      'développer((x+1)^2)',
      r'\operatorname{developper}\left(\left(x+1\right)^{2}\right)',
    );
    tape('moyenne(2;4;9)', r'\operatorname{moyenne}\left(2;4;9\right)');
    tape('moyenne(2,4,9)', r'\operatorname{moyenne}\left(2;4;9\right)');
    tape('Écart-type(2;4)', r'\operatorname{ecarttype}\left(2;4\right)');
    tape('tangente(f;2)', r'\operatorname{tangente}\left(f;2\right)');
    tape('pgcd(12;18)=', r'\operatorname{pgcd}\left(12;18\right)=');

    test('tangente(x) reste la fonction tangente', () {
      expect(lireSaisie('tangente(x)').latex, contains(r'\tan'));
    });

    test('ce qui est tapé se calcule', () {
      for (final (texte, giac) in [
        ('développer((x+1)^2)', 'expand(((x+1))^(2))'),
        ('moyenne(2;4;9)', 'mean([2,4,9])'),
        ('Écart-type(2;4)', 'stddev([2,4])'),
        ('arrondi(2/3;2)', 'round((2)/(3),2)'),
      ]) {
        expect(analyserLatex(lireSaisie(texte).latex!).giac, giac);
      }
    });
  });
}
