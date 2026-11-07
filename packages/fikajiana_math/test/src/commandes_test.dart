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
}
