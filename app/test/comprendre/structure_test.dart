import 'dart:math' as math;

import 'package:fikajiana/comprendre/structure.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/reconnaissance/lecteur.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lit un morceau d'après sa position : le faux modèle reconnaît chaque case.
class _Lecteur extends Lecteur {
  new(this.lectures);
  final String Function(List<Trait>) lectures;
  int appels = 0;

  @override
  Future<String> lire(List<Trait> traits) async {
    appels++;
    return lectures(traits);
  }
}

double _c0(List<Trait> t) => t.first.points.first.x;

void main() {
  late Encre encre;
  setUp(() => encre = Encre());

  Trait trait(double x, double y, double l, double h) {
    encre.commencer(PointEncre(x, y, 0.1));
    for (var i = 1; i <= 8; i++) {
      encre.prolonger(PointEncre(x + l * i / 8, y + h * i / 8, 0.1));
    }
    encre.terminer();
    return encre.traits.last;
  }

  void chiffre(double x, double y) => trait(x, y, 20, 40);

  /// Un tracé qui ne ressemble à rien.
  void griffonner(double x, double y) {
    final r = math.Random(3);
    encre.commencer(PointEncre(x, y, 0.1));
    for (var i = 0; i < 80; i++) {
      encre.prolonger(
        PointEncre(x + r.nextDouble() * 40, y + r.nextDouble() * 40, 0.1),
      );
    }
    encre.terminer();
  }

  void moins(double x, double y) => trait(x, y + 20, 18, 2);

  /// `det (1 -5 3 ; 4 -2 -8 ; 3 5 7)`, comme sur le Pad 7.
  void matrice3() {
    trait(0, 40, 20, 40); // d
    trait(30, 45, 10, 35); // e
    trait(50, 35, 8, 45); // t
    trait(80, 0, 12, 200); // (
    chiffre(110, 10);
    moins(190, 10);
    chiffre(215, 10);
    chiffre(300, 10);
    chiffre(110, 75);
    moins(190, 75);
    chiffre(215, 75);
    moins(280, 75);
    chiffre(305, 75);
    chiffre(110, 140);
    chiffre(215, 140);
    chiffre(300, 140);
    trait(350, 0, -12, 200); // )
  }

  group('une matrice se voit sur ses traits', () {
    test('trois lignes, trois colonnes, le moins reste avec son chiffre', () {
      matrice3();
      final s = trouverStructure(encre.traits)! as StructureMatrice;
      expect(s.cases, hasLength(3));
      expect(s.cases.map((l) => l.length), everyElement(3));
      expect(s.cases[0][1], hasLength(2));
      expect(s.cases[1][2], hasLength(2));
      expect(s.tete, hasLength(3));
    });

    test('se lit case par case, en vrai déterminant', () async {
      matrice3();
      // La ligne se lit sans ses moins, que les traits donnent.
      final l = _Lecteur((t) {
        if (t.length == 3 && _c0(t) < 80) return 'd e t';
        return '1 2 3';
      });
      final lu = await lireStructure(l, encre.traits);
      // Des traits droits, ici : chaque chiffre se reconnaît comme un 1.
      expect(lu, r'\det \begin{pmatrix}1&-1&1\\1&-1&-1\\1&1&1\end{pmatrix}');
    });

    test('A = devant une matrice la déclare, sans det (Pad 7)', () async {
      matrice3();
      final l = _Lecteur((t) {
        if (t.length == 3 && _c0(t) < 80) return 'A =';
        return '1 2 3';
      });
      final lu = await lireStructure(l, encre.traits);
      expect(lu, startsWith(r'A=\begin{pmatrix}'));
      expect(lu, isNot(contains(r'\det')));
    });

    test('-2 -8 serrés restent deux cases', () {
      trait(0, 0, 10, 130);
      chiffre(20, 5);
      moins(70, 5);
      chiffre(90, 5);
      moins(112, 5);
      chiffre(132, 5);
      chiffre(20, 75);
      moins(70, 75);
      chiffre(90, 75);
      chiffre(132, 75);
      trait(170, 0, -10, 130);
      final s = trouverStructure(encre.traits)! as StructureMatrice;
      expect(s.cases.map((l) => l.length), [3, 3]);
    });

    test('une case illisible rend la main au modèle', () async {
      trait(0, 0, 10, 130);
      griffonner(20, 5);
      chiffre(90, 5);
      griffonner(20, 75);
      chiffre(90, 75);
      trait(130, 0, -10, 130);
      final l = _Lecteur((t) => r'\overbrace{\alpha}');
      expect(await lireStructure(l, encre.traits), isNull);
    });

    test('une parenthèse sur une seule ligne n’en est pas une', () {
      trait(0, 0, 8, 50);
      chiffre(20, 5);
      chiffre(60, 5);
      trait(90, 0, -8, 50);
      expect(trouverStructure(encre.traits), isNull);
    });

    test('une matrice colonne', () {
      trait(0, 0, 10, 130);
      chiffre(20, 5);
      chiffre(20, 75);
      trait(60, 0, -10, 130);
      final s = trouverStructure(encre.traits)! as StructureMatrice;
      expect(s.cases.map((l) => l.length), [1, 1]);
    });
  });

  group('une flèche se voit', () {
    test('une flèche qui touche ses lettres, d’un seul trait', () {
      encre.commencer(const PointEncre(0, 10, 0.1));
      for (var i = 1; i <= 20; i++) {
        encre.prolonger(PointEncre(i * 5.0, i > 18 ? 4.0 + i - 18 : 10, 0.1));
      }
      encre.terminer();
      trait(5, 14, 30, 45);
      trait(50, 14, 30, 45);
      expect(trouverStructure(encre.traits), isA<StructureFleche>());
    });

    test(
      'la barre du e de det, devant une matrice, n’en est pas une',
      () async {
        matrice3();
        final l = _Lecteur(
          (t) => t.length == 3 && _c0(t) < 80 ? 'd e t' : '1 2 3',
        );
        expect(await lireStructure(l, encre.traits), startsWith(r'\det '));
      },
    );

    test('une pointe large et des lettres qui dépassent, sous une norme', () {
      trait(0, 0, 3, 54);
      trait(9, 5, 4, 44);
      trait(26, 10, 29, 45);
      trait(38, 34, 15, 4);
      trait(38, -10, 36, 3);
      trait(57, 5, 28, 41);
      trait(66, -22, 15, 27);
      trait(96, 8, 3, 46);
      trait(113, 7, 2, 46);
      final s = trouverStructure(encre.traits)! as StructureNorme;
      expect(trouverStructure(s.dedans), isA<StructureFleche>());
    });

    test('au-dessus de deux lettres, avec sa pointe', () async {
      trait(0, 0, 100, 2);
      trait(95, -8, 8, 16);
      trait(5, 20, 30, 45);
      trait(50, 20, 30, 45);
      final s = trouverStructure(encre.traits)! as StructureFleche;
      expect(s.nom, hasLength(2));
      // Des traits droits, ici : le tracé doute, et le modèle lit le nom.
      final lu = await lireStructure(_Lecteur((_) => 'A B'), encre.traits);
      expect(lu, r'\overrightarrow{AB}');
    });

    test('une fraction n’est pas une flèche', () {
      chiffre(30, -50);
      trait(0, 0, 100, 2);
      chiffre(30, 10);
      expect(trouverStructure(encre.traits), isNull);
    });

    test('un grand mot sous le trait n’est pas un vecteur', () async {
      trait(0, 0, 100, 2);
      griffonner(5, 20);
      griffonner(50, 20);
      final lu = await lireStructure(_Lecteur((_) => 'x + 1'), encre.traits);
      expect(lu, isNull);
    });
  });

  group('une norme se voit', () {
    test('deux barres de chaque côté', () async {
      trait(0, 0, 3, 70);
      trait(12, 0, 3, 70);
      chiffre(30, 15);
      chiffre(60, 15);
      trait(90, 0, 3, 70);
      trait(102, 0, 3, 70);
      final s = trouverStructure(encre.traits)! as StructureNorme;
      expect(s.dedans, hasLength(2));
      final lu = await lireStructure(_Lecteur((_) => 'AB'), encre.traits);
      expect(lu, r'\|AB\|');
    });

    test('avec une flèche au-dessus, elle reste une norme', () async {
      trait(25, -20, 60, 2);
      trait(80, -28, 8, 16);
      trait(0, 0, 3, 50);
      trait(12, 0, 3, 50);
      chiffre(30, 5);
      chiffre(60, 5);
      trait(90, 0, 3, 50);
      trait(102, 0, 3, 50);
      expect(trouverStructure(encre.traits), isA<StructureNorme>());
    });

    test('1+1 n’est pas une norme', () {
      trait(0, 0, 3, 50);
      trait(30, 15, 20, 2);
      trait(40, 5, 2, 20);
      trait(70, 0, 3, 50);
      expect(trouverStructure(encre.traits), isNull);
    });
  });

  test('une ligne ordinaire ne coûte aucune lecture de plus', () async {
    chiffre(0, 0);
    chiffre(40, 0);
    chiffre(80, 0);
    final l = _Lecteur((_) => '1 2 3');
    expect(await lireAuMieux(l, encre.traits), '1 2 3');
    expect(l.appels, 1);
  });

  group('ressemble à det', () {
    test('les lectures relevées', () {
      for (final t in [
        'd e t',
        r'\alpha +',
        'c t +',
        r'\det',
        'det',
        'de t',
        r'\tau l e t',
      ]) {
        expect(ressembleADet(t), isTrue, reason: t);
      }
    });
    test('ce que le modèle lit d’un det seul', () {
      expect(ressembleADet(r'\phi e^{\pi}'), isTrue);
    });

    test('pas le reste', () {
      for (final t in ['', '2', 'A', 'x', '2 x', 'x+1', '3a']) {
        expect(ressembleADet(t), isFalse, reason: t);
      }
    });
  });
}
