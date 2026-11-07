import 'package:fikajiana/geometrie/atelier.dart';
import 'package:fikajiana/graphe/courbes.dart';
import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Demande d'Antsa : `C : x^2+y^3=0` sur la Feuille est l'objet C de la
  // Figure ; un nom déjà pris devient C_1.
  group('une courbe nommée', () {
    test('se lit avec son nom', () {
      final c = lireCourbe('C : x^{2}+y^{3}=0')!;
      expect(c.nom, 'C');
      expect(c.genre, GenreCourbe.implicite);
      expect(estCourbeSeule('C : x^{2}+y^{3}=0'), isTrue);
      expect(lireCourbe('f(x)=x^{2}')!.nom, isNull);
    });

    test('un nom déjà pris par une courbe devient C_1, puis C_2', () {
      final courbes = Courbes();
      expect(courbes.ajouter('C : x^{2}+y^{2}=1'), isTrue);
      expect(courbes.ajouter('C : x^{2}+y^{3}=0'), isTrue);
      expect(courbes.ajouter('C : y=x'), isTrue);
      expect(courbes.liste.map((c) => c.nom), ['C', 'C_1', 'C_2']);
      expect(courbes.liste[1].latex, startsWith('C_1 :'));
    });

    test('la même courbe, au même nom, ne se double pas', () {
      final courbes = Courbes()..ajouter('C : x^{2}+y^{2}=1');
      expect(courbes.ajouter('C : x^{2}+y^{2}=1'), isTrue);
      expect(courbes.liste, hasLength(1));
    });

    test('un point C de la Figure garde son nom ; la courbe prend C_1', () {
      final atelier = Atelier();
      final courbes = Courbes();
      courbes
        ..nomsPris = (() => atelier.figure.noms)
        ..ajouter('');
      atelier
        ..nomsReserves = (() => courbes.noms)
        ..placerObjet(const PointLu('C', 1, 2));
      courbes.ajouter('C : x^{2}+y^{3}=0');
      expect(courbes.liste.single.nom, 'C_1');
      // Et un nouvel objet de la Figure ne prend pas C_1.
      expect(atelier.figure.noms, isNot(contains('C_1')));
    });
  });
}
