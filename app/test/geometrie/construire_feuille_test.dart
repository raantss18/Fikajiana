import 'dart:math' as math;

import 'package:fikajiana/geometrie/atelier.dart';
import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter_test/flutter_test.dart';

// Valeurs de référence calculées à la main, notées à chaque test.
void main() {
  int? idDe(Atelier a, String nom) {
    for (final id in a.figure.objets) {
      if (a.figure.apparence(id).nom == nom) return id;
    }
    return null;
  }

  FormeGeo? forme(Atelier a, String nom) => a.formes[idDe(a, nom)];

  Atelier triangle() => Atelier()
    ..placerObjet(const PointLu('A', 0, 0))
    ..placerObjet(const PointLu('B', 4, 0))
    ..placerObjet(const PointLu('C', 1, 3));

  bool construire(Atelier a, String ecrit) =>
      a.construire(lireCommande(ecrit)!);

  /// La forme ajoutée en dernier, du type demandé.
  T derniere<T extends FormeGeo>(Atelier a) =>
      a.formes.values.whereType<T>().last;

  void passePar(FormeGeo? f, double x, double y) =>
      expect(distanceA(f, x, y), closeTo(0, 1e-9));

  test('parallèle à (AB) par C : y = 3, et suit A', () {
    final a = triangle();
    expect(construire(a, 'd=parallèle((AB);C)'), isTrue);
    final d = forme(a, 'd');
    passePar(d, 0, 3);
    passePar(d, 7, 3);
    // (AB) est tracée, une seule fois.
    expect(a.formes.values.whereType<DroiteGeo>(), hasLength(2));
    // A(0;1) : (AB) a pour direction (4;−1), la parallèle passe par (5;2).
    a.placerObjet(const PointLu('A', 0, 1));
    passePar(forme(a, 'd'), 5, 2);
  });

  test('perpendiculaire à une droite nommée par C : x = 1', () {
    final a = triangle();
    expect(construire(a, 'd=(AB)'), isTrue);
    expect(construire(a, 'perpendiculaire(d;C)'), isTrue);
    final p = derniere<DroiteGeo>(a);
    passePar(p, 1, 0);
    passePar(p, 1, -5);
  });

  test('une droite nommée absente : rien ne change', () {
    final a = triangle();
    final avant = a.figure.objets.length;
    expect(construire(a, 'parallèle(d;C)'), isFalse);
    expect(a.figure.objets, hasLength(avant));
  });

  test('bissectrice de l’angle en B (45°) : direction 157,5°', () {
    final a = triangle();
    expect(construire(a, 'bissectrice(A;B;C)'), isTrue);
    const t = 157.5 * math.pi / 180;
    passePar(derniere<DroiteGeo>(a), 4 + math.cos(t), math.sin(t));
  });

  test('deux tangentes au cercle de centre A, de rayon 2, par B', () {
    final a = triangle();
    expect(construire(a, 'k=cercle(A;2)'), isTrue);
    expect(construire(a, 'T=tangente(k;B)'), isTrue);
    // Points de contact (1;±√3) : cos θ = 2/4 (à la main).
    final t1 = forme(a, 'T');
    final t2 = forme(a, 'T_1');
    for (final t in [t1, t2]) {
      passePar(t, 4, 0);
      expect(distanceA(t, 0, 0), closeTo(2, 1e-9));
    }
    final contacts = [
      distanceA(t1, 1, math.sqrt(3)),
      distanceA(t2, 1, math.sqrt(3)),
    ]..sort();
    expect(contacts.first, closeTo(0, 1e-9));
  });

  test('une tangente seule par un point du cercle', () {
    final a = Atelier()
      ..placerObjet(const PointLu('A', 0, 0))
      ..placerObjet(const PointLu('M', 2, 0));
    construire(a, 'k=cercle(A;2)');
    expect(construire(a, 'tangente(k;M)'), isTrue);
    passePar(derniere<DroiteGeo>(a), 2, 5);
    expect(a.formes.values.whereType<DroiteGeo>(), hasLength(1));
  });

  test("A'=symétrique(A;B) = (8;0), puis suit B", () {
    final a = triangle();
    expect(construire(a, "A'=symétrique(A;B)"), isTrue);
    final p = forme(a, "A'")! as PointGeo;
    expect((p.x, p.y), (8, 0));
    a.placerObjet(const PointLu('B', 1, 1));
    final q = forme(a, "A'")! as PointGeo;
    expect((q.x, q.y), (2, 2));
  });

  test('symétrique de C par rapport à (AB) = (1;−3)', () {
    final a = triangle();
    expect(construire(a, 'E=symétrique(C;(AB))'), isTrue);
    final p = forme(a, 'E')! as PointGeo;
    expect(p.x, closeTo(1, 1e-9));
    expect(p.y, closeTo(-3, 1e-9));
  });

  test('H=projeté(C;(AB)) = (1;0), et suit C', () {
    final a = triangle();
    expect(construire(a, 'H=projeté(C;(AB))'), isTrue);
    var h = forme(a, 'H')! as PointGeo;
    expect(h.x, closeTo(1, 1e-9));
    expect(h.y, closeTo(0, 1e-9));
    a.placerObjet(const PointLu('C', 3, 5));
    h = forme(a, 'H')! as PointGeo;
    expect(h.x, closeTo(3, 1e-9));
  });

  test('I=intersection((AC);(BD)) = (4;12) : y = 3x et x = 4', () {
    final a = triangle()..placerObjet(const PointLu('D', 4, 3));
    expect(construire(a, 'I=intersection((AC);(BD))'), isTrue);
    final i = forme(a, 'I')! as PointGeo;
    expect(i.x, closeTo(4, 1e-9));
    expect(i.y, closeTo(12, 1e-9));
  });

  test('triangle(A;B;C) puis polygone(A;B;C;D)', () {
    final a = triangle()..placerObjet(const PointLu('D', 0, 3));
    expect(construire(a, 'triangle(ABC)'), isTrue);
    expect(construire(a, 'polygone(A;B;C;D)'), isTrue);
    final polygones = a.formes.values.whereType<PolygoneGeo>().toList();
    expect(polygones.map((p) => p.sommets.length), [3, 4]);
    // Écrit deux fois, il ne se double pas.
    construire(a, 'triangle(A;B;C)');
    expect(a.formes.values.whereType<PolygoneGeo>(), hasLength(2));
  });

  test('un nom déjà pris devient C_1', () {
    final a = triangle();
    expect(construire(a, 'C=milieu(A;B)'), isTrue);
    final m = forme(a, 'C_1')! as PointGeo;
    expect((m.x, m.y), (2, 0));
    // Relancée, la même construction garde son nom.
    construire(a, 'C=milieu(A;B)');
    expect(idDe(a, 'C_2'), isNull);
  });

  test('un seul Annuler défait la construction', () {
    final a = triangle();
    final avant = a.figure.objets.length;
    construire(a, 'H=projeté(C;(AB))');
    a.annuler();
    expect(a.figure.objets, hasLength(avant));
  });
}
