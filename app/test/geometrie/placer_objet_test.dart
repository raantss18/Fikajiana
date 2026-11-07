import 'package:fikajiana/geometrie/atelier.dart';
import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PointGeo? point(Atelier a, String nom) {
    for (final id in a.figure.objets) {
      if (a.figure.apparence(id).nom == nom) return a.formes[id] as PointGeo?;
    }
    return null;
  }

  group('placer depuis la feuille', () {
    test('un point porte son nom et ses coordonnées', () {
      final a = Atelier()..placerObjet(const PointLu('A', 1, 2));
      expect((point(a, 'A')!.x, point(a, 'A')!.y), (1, 2));
    });

    test('le même nom déplace au lieu de doubler', () {
      final a = Atelier()
        ..placerObjet(const PointLu('A', 1, 2))
        ..placerObjet(const PointLu('A', 3, 4));
      expect(a.figure.objets, hasLength(1));
      expect((point(a, 'A')!.x, point(a, 'A')!.y), (3, 4));
    });

    test('un vecteur AB part de A, s’il existe', () {
      final a = Atelier()
        ..placerObjet(const PointLu('A', 1, 2))
        ..placerObjet(const VecteurLu('AB', 1, 3));
      expect((point(a, 'B')!.x, point(a, 'B')!.y), (2, 5));
      expect(a.formes.values.whereType<DroiteGeo>().single.vecteur, isTrue);
    });

    test('un vecteur AB sans A part de l’origine', () {
      final a = Atelier()..placerObjet(const VecteurLu('AB', 1, 3));
      expect((point(a, 'A')!.x, point(a, 'A')!.y), (0, 0));
      expect((point(a, 'B')!.x, point(a, 'B')!.y), (1, 3));
    });

    test('le même vecteur ne se double pas', () {
      final a = Atelier()
        ..placerObjet(const VecteurLu('AB', 1, 3))
        ..placerObjet(const VecteurLu('AB', 1, 3));
      expect(a.formes.values.whereType<DroiteGeo>(), hasLength(1));
    });

    test('un seul Annuler enlève tout', () {
      final a = Atelier()..placerObjet(const VecteurLu('u', 1, 3));
      expect(a.figure.objets, hasLength(3));
      a.annuler();
      expect(a.figure.objets, isEmpty);
    });
  });
}
