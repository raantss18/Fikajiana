import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:test/test.dart';

/// Les valeurs exactes se vérifient contre SymPy au banc sur l'appareil
/// (`tool/banc/references_feuille.py`, problème « lois de probabilité ») ;
/// ici, ce qui est lu et ce qui est demandé à Giac.
void main() {
  /// Les valeurs de la feuille après la déclaration [ligne].
  Map<String, String> apres(String ligne) {
    final a = analyserLatex(ligne);
    return {a.nomValeur!: a.giac};
  }

  group('déclarer une loi', () {
    for (final (ecrit, genre, parametres) in [
      (r'X\sim B(10;0{,}3)', GenreLoi.binomiale, ['10', '0.3']),
      (
        r'X \sim \mathcal{B}\left(10;0{,}3\right)',
        GenreLoi.binomiale,
        ['10', '0.3'],
      ),
      (r'X\sim B(20,\frac{1}{4})', GenreLoi.binomiale, ['20', '(1)/(4)']),
      (r'Y\sim\mathcal{N}(100;15^{2})', GenreLoi.normale, ['100', '(15)^(2)']),
      (r'Z\sim\mathcal{P}(3)', GenreLoi.poisson, ['3']),
      (r'T\sim\mathcal{G}(0{,}2)', GenreLoi.geometrique, ['0.2']),
      (r'D\sim\mathcal{E}(0{,}5)', GenreLoi.exponentielle, ['0.5']),
      (r'U\sim\mathcal{U}(0;10)', GenreLoi.uniforme, ['0', '10']),
      ('X ∼ B(10;0,3)', GenreLoi.binomiale, ['10', '0.3']),
    ]) {
      test(ecrit, () {
        final a = analyserLatex(ecrit);
        expect(a.type, TypeExpression.calcul);
        expect(a.nomValeur, isNotNull);
        final loi = Loi.lire(a.giac)!;
        expect(loi.genre, genre);
        expect(loi.parametres.map((p) => p.replaceAll(' ', '')), parametres);
      });
    }

    test('une loi inconnue ou des paramètres en trop se refusent', () {
      expect(() => analyserLatex(r'X\sim Q(3)'), throwsA(isA<ErreurLatex>()));
      expect(
        () => analyserLatex(r'X\sim B(10;0{,}3;2)'),
        throwsA(isA<ErreurLatex>()),
      );
    });
  });

  group('probabilités d’une loi discrète', () {
    final x = apres(r'X\sim B(10;0{,}3)');
    String giac(String l) => analyserLatex(l, valeurs: x).giac;
    String somme(int a, int b) =>
        'sum(comb((10),j)*(0.3)^j*(1-(0.3))^((10)-j),j,$a,$b)';

    test('P(X=3), P(X≤3), P(X<3), P(X≥8), P(X>8), P(2≤X<5)', () {
      expect(giac('P(X=3)='), somme(3, 3));
      expect(giac(r'P(X\le3)='), somme(0, 3));
      expect(giac(r'P(X\leqslant 3)='), somme(0, 3));
      expect(giac('P(X<3)='), somme(0, 2));
      expect(giac(r'P(X\geq 8)='), somme(8, 10));
      expect(giac('P(X>8)='), somme(9, 10));
      expect(giac(r'P(2\le X<5)='), somme(2, 4));
      expect(giac(r'P(3\ge X)='), somme(0, 3));
    });

    test('bornes non entières, hors du support, événement impossible', () {
      expect(giac(r'P(X\le 2{,}5)='), somme(0, 2));
      expect(giac(r'P(X\ge -4)='), somme(0, 10));
      expect(giac('P(X>12)='), '0');
      expect(giac(r'P(5\le X\le 2)='), '0');
    });

    test('Poisson et géométrique : vers l’infini par le complément', () {
      final z = apres(r'Z\sim\mathcal{P}(3)');
      expect(
        analyserLatex(r'P(Z\ge 2)=', valeurs: z).giac,
        '1-sum(exp(-(3))*(3)^j/factorial(j),j,0,1)',
      );
      final t = apres(r'T\sim\mathcal{G}(0{,}2)');
      expect(
        analyserLatex('P(T=1)=', valeurs: t).giac,
        'sum((1-(0.2))^(j-1)*(0.2),j,1,1)',
      );
      // La géométrique commence à 1.
      expect(analyserLatex(r'P(T\ge 1)=', valeurs: t).giac, '1');
    });

    test('une variable non déclarée n’est pas une loi', () {
      expect(() => analyserLatex(r'P(X\le3)='), throwsA(isA<ErreurLatex>()));
    });

    test('borne non numérique : refusée', () {
      expect(() => giac(r'P(X\le a)='), throwsA(isA<ErreurLatex>()));
    });
  });

  group('lois continues', () {
    final y = apres(r'Y\sim\mathcal{N}(100;15^{2})');
    String giac(String l) => analyserLatex(l, valeurs: y).giac;

    test('normale : P(Y≤115) par erf, P(Y=100)=0, intervalle', () {
      expect(
        giac(r'P(Y\le115)=').replaceAll(' ', ''),
        '((1+erf((115-(100))/sqrt(2*((15)^(2)))))/2)-(0)',
      );
      expect(giac('P(Y=100)='), '0');
      expect(giac(r'P(85\le Y\le115)='), contains('erf((85-(100))'));
      expect(giac('P(Y>130)='), startsWith('(1)-('));
    });

    test('exponentielle et uniforme', () {
      final d = apres(r'D\sim\mathcal{E}(0{,}5)');
      expect(
        analyserLatex(r'P(D\le2)=', valeurs: d).giac,
        '((1-exp(-(0.5)*max(2,0))))-(0)',
      );
      final u = apres(r'U\sim\mathcal{U}(0;10)');
      expect(
        analyserLatex(r'P(2\le U\le5)=', valeurs: u).giac,
        '(min(1,max(0,(5-(0))/((10)-(0)))))-'
        '(min(1,max(0,(2-(0))/((10)-(0)))))',
      );
    });
  });

  group('espérance, variance, écart type', () {
    test('binomiale, normale, géométrique', () {
      final x = apres(r'X\sim B(10;0{,}3)');
      expect(analyserLatex('E(X)=', valeurs: x).giac, '(10)*(0.3)');
      expect(analyserLatex('V(X)=', valeurs: x).giac, '(10)*(0.3)*(1-(0.3))');
      expect(
        analyserLatex(r'\sigma(X)=', valeurs: x).giac,
        'sqrt((10)*(0.3)*(1-(0.3)))',
      );
      expect(analyserLatex('E(X)=', valeurs: x).demandeResultat, isTrue);
      final y = apres(r'Y\sim\mathcal{N}(100;15^{2})');
      expect(analyserLatex('V(Y)=', valeurs: y).giac, '((15)^(2))');
      final t = apres(r'T\sim\mathcal{G}(0{,}2)');
      expect(analyserLatex('E(T)=', valeurs: t).giac, '1/(0.2)');
    });

    test('E(X) sans loi reste un produit', () {
      expect(analyserLatex('E(X)=').giac, isNot(contains('sum')));
    });
  });

  group('seuils', () {
    test('discret : P(X≤k)≥0,95, le plus petit entier', () {
      final x = apres(r'X\sim B(10;0{,}3)');
      final a = analyserLatex(r'P(X\le k)\ge0{,}95', valeurs: x);
      expect(a.type, TypeExpression.equation);
      expect(a.inconnues, ['k']);
      expect(a.giac, 'solve(k>=binomial_icdf((10),(0.3),0.95),k)');
      expect(
        () => analyserLatex(r'P(X\le k)=0{,}95', valeurs: x),
        throwsA(isA<ErreurLatex>()),
      );
    });

    test('continu : P(Y≤t)=0,975 et P(Y≥t)=0,05', () {
      final y = apres(r'Y\sim\mathcal{N}(100;15^{2})');
      expect(
        analyserLatex(r'P(Y\le t)=0{,}975', valeurs: y).giac,
        'solve(t=evalf(normald_icdf((100),sqrt(((15)^(2))),0.975)),t)',
      );
      expect(
        analyserLatex(r'P(Y\ge t)=0{,}05', valeurs: y).giac,
        'solve(t=evalf(normald_icdf((100),sqrt(((15)^(2))),1-(0.05))),t)',
      );
    });
  });

  group('lu à la main : minuscules (le modèle lit x pour X)', () {
    final x = apres(r'X\sim B(10;0{,}3)');

    test('p(x≤3) et E(x) valent P(X≤3) et E(X)', () {
      expect(
        analyserLatex(r'p(x\le3)=', valeurs: x).giac,
        analyserLatex(r'P(X\le3)=', valeurs: x).giac,
      );
      expect(
        analyserLatex('E(x)=', valeurs: x).giac,
        analyserLatex('E(X)=', valeurs: x).giac,
      );
    });

    test('le seuil t reste t même si T est une loi (banc, Pad 7)', () {
      final valeurs = {
        ...apres(r'T\sim\mathcal{G}(0{,}2)'),
        ...apres(r'Y\sim\mathcal{N}(100;15^{2})'),
      };
      final a = analyserLatex(r'P(Y\le t)=0{,}975', valeurs: valeurs);
      expect(a.inconnues, ['t']);
      expect(a.giac, contains('normald_icdf'));
    });

    test('jamais si x vaut déjà autre chose, ni pour une fonction p', () {
      final avecX = {...x, 'x': '2'};
      expect(
        analyserLatex('E(x)=', valeurs: avecX).giac,
        isNot(analyserLatex('E(X)=', valeurs: x).giac),
      );
      final f = analyserLatex('p(x)=x^{2}', valeurs: x);
      expect(f.type, TypeExpression.fonction);
    });
  });
}
