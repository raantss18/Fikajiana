import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:test/test.dart';

void main() {
  void lit(
    String ecrit,
    GenreCommande genre,
    List<String> points, {
    double? rayon,
    String? nom,
  }) {
    test(ecrit, () {
      final c = lireCommande(ecrit);
      expect(c, isNotNull);
      expect(c!.genre, genre);
      expect(c.points, points);
      expect(c.rayon, rayon);
      expect(c.nom, nom);
    });
  }

  group('ce qu’on écrit en géométrie', () {
    lit('cercle(A;2)', GenreCommande.cercleRayon, ['A'], rayon: 2);
    lit('cercle(A,3,5)', GenreCommande.cercleRayon, ['A'], rayon: 3.5);
    lit(r'cercle(A;\frac{1}{2})', GenreCommande.cercleRayon, ['A'], rayon: .5);
    lit('cercle(A;B)', GenreCommande.cercle, ['A', 'B']);
    lit('c e r c l e ( A ; 2 )', GenreCommande.cercleRayon, ['A'], rayon: 2);
    lit(r'\mathrm{cercle}\left(A;2\right)', GenreCommande.cercleRayon, [
      'A',
    ], rayon: 2);
    lit('(AB)', GenreCommande.droite, ['A', 'B']);
    lit(r'\left( A B \right)', GenreCommande.droite, ['A', 'B']);
    lit('droite(A;B)', GenreCommande.droite, ['A', 'B']);
    lit('[AB]', GenreCommande.segment, ['A', 'B']);
    lit('[AB)', GenreCommande.demiDroite, ['A', 'B']);
    lit('milieu(A;B)', GenreCommande.milieu, ['A', 'B']);
    lit('I=milieu(A;B)', GenreCommande.milieu, ['A', 'B'], nom: 'I');
    lit('médiatrice(A;B)', GenreCommande.mediatrice, ['A', 'B']);
  });

  group('rien d’autre', () {
    for (final s in [
      '(x+1)',
      'f(x)',
      'cercle(x;2)',
      'cercle(A;-2)',
      'AB',
      'bonjour(A;B)',
      '(AB',
      'A(1;2)',
    ]) {
      test(s, () => expect(lireCommande(s), isNull));
    }
  });

  test('se tape au clavier', () {
    expect(lireSaisie('cercle(A;2)').latex, 'cercle(A;2)');
    expect(lireSaisie('[AB]').latex, '[AB]');
  });

  _constructions();
}

void _constructions() {
  void lit(
    String ecrit,
    GenreCommande genre,
    List<String> points, {
    List<String> objets = const [],
    String? nom,
    List<Type>? arguments,
  }) {
    test(ecrit, () {
      final c = lireCommande(ecrit);
      expect(c, isNotNull);
      expect(c!.genre, genre);
      expect(c.points, points);
      expect(c.objets, objets);
      expect(c.nom, nom);
      if (arguments != null) {
        expect(c.arguments.map((a) => a.runtimeType), arguments);
      }
    });
  }

  group('les constructions à arguments', () {
    lit(
      'parallèle((AB);C)',
      GenreCommande.parallele,
      ['A', 'B', 'C'],
      arguments: [ArgLigne, ArgPoint],
    );
    lit(
      'parallele(C;(AB))',
      GenreCommande.parallele,
      ['A', 'B', 'C'],
      arguments: [ArgLigne, ArgPoint],
    );
    lit(
      r'\text{parallèle}\left(\left(AB\right);C\right)',
      GenreCommande.parallele,
      ['A', 'B', 'C'],
    );
    lit(
      'parallèle(d;C)',
      GenreCommande.parallele,
      ['C'],
      objets: ['d'],
      arguments: [ArgNomme, ArgPoint],
    );
    lit(
      'd_1=parallèle(d;C)',
      GenreCommande.parallele,
      ['C'],
      objets: ['d'],
      nom: 'd_1',
    );
    lit('perpendiculaire((AB);C)', GenreCommande.perpendiculaire, [
      'A',
      'B',
      'C',
    ]);
    lit(
      'perpendiculaire(D;C)',
      GenreCommande.perpendiculaire,
      ['C'],
      objets: ['D'],
    );
    lit('bissectrice(A;B;C)', GenreCommande.bissectrice, ['A', 'B', 'C']);
    lit(
      r'tangente(\mathcal{C};A)',
      GenreCommande.tangente,
      ['A'],
      objets: ['C'],
    );
    lit(
      "A'=symétrique(A;B)",
      GenreCommande.symetrique,
      ['A', 'B'],
      nom: "A'",
      arguments: [ArgPoint, ArgPoint],
    );
    lit(
      'symetrique(A;(BC))',
      GenreCommande.symetrique,
      ['A', 'B', 'C'],
      arguments: [ArgPoint, ArgLigne],
    );
    lit('symétrique(A;d)', GenreCommande.symetrique, ['A'], objets: ['d']);
    lit(
      'H=projeté(A;(BC))',
      GenreCommande.projete,
      ['B', 'C', 'A'],
      nom: 'H',
      arguments: [ArgLigne, ArgPoint],
    );
    lit('I=intersection((AB);(CD))', GenreCommande.intersection, [
      'A',
      'B',
      'C',
      'D',
    ], nom: 'I');
    lit(
      'intersection(d;(CD))',
      GenreCommande.intersection,
      ['C', 'D'],
      objets: ['d'],
    );
    lit('triangle(A;B;C)', GenreCommande.polygone, ['A', 'B', 'C']);
    lit('triangle(ABC)', GenreCommande.polygone, ['A', 'B', 'C']);
    lit('polygone(A;B;C;D)', GenreCommande.polygone, ['A', 'B', 'C', 'D']);
    lit('d=(AB)', GenreCommande.droite, ['A', 'B'], nom: 'd');
  });

  group('pas une construction', () {
    for (final s in [
      'tangente(f;2)',
      'parallèle(A;B;C)',
      'bissectrice(A;B)',
      'triangle(A;B)',
      'triangle(A;A;B)',
      'symétrique(2;B)',
      'angle(A;B;C)',
      'aire(ABC)',
    ]) {
      test(s, () => expect(lireCommande(s), isNull));
    }
  });

  test('se tapent au clavier', () {
    expect(lireSaisie('parallèle((AB);C)').latex, 'parallèle((AB);C)');
    expect(lireSaisie('triangle(A;B;C)').latex, 'triangle(A;B;C)');
  });
}
