import 'dart:ui';

import 'package:fikajiana/comprendre/calcul_feuille.dart';
import 'package:fikajiana/comprendre/fraction_ecrite.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/moteur/giac.dart';
import 'package:fikajiana/moteur/moteur.dart';
import 'package:fikajiana/reconnaissance/lecteur.dart';
import 'package:flutter_test/flutter_test.dart';

Trait trait(double x0, double y0, double x1, double y1) {
  final t = Trait(PointEncre(x0, y0, 1));
  return Trait.deplace(t, [
    for (var i = 0; i <= 10; i++)
      PointEncre(x0 + (x1 - x0) * i / 10, y0 + (y1 - y0) * i / 10, 1),
  ]);
}

/// Un signe tout droit, vertical : il n'est pas pris pour une barre.
Trait signe(double x) => trait(x, 10, x, 40);

/// Une barre de fraction en ligne, qui monte vers la droite.
Trait barre(double x) => trait(x, 45, x + 20, 5);

Rect cadre(Trait t) => t.points
    .map((p) => Rect.fromLTWH(p.x, p.y, 0, 0))
    .reduce((a, b) => a.expandToInclude(b));

class _Lecteur extends Lecteur {
  new(this.reponse);

  final String reponse;
  int lectures = 0;

  @override
  Future<String> lire(List<Trait> traits) async {
    lectures++;
    return reponse;
  }
}

class _Moteur implements Moteur {
  @override
  Future<ReponseGiac> calculer(String entree, {bool degres = false}) async =>
      const ReponseGiac(exact: '1/3', latex: r'\frac{1}{3}', approche: '0.33');

  @override
  void interrompre() {}
}

void main() {
  group('dans la feuille', () {
    void ecrire(Encre e, List<(double, double, double, double)> traits) {
      for (final (x0, y0, x1, y1) in traits) {
        e.commencer(PointEncre(x0, y0, 1));
        for (var i = 1; i <= 10; i++) {
          e.prolonger(
            PointEncre(x0 + (x1 - x0) * i / 10, y0 + (y1 - y0) * i / 10, 1),
          );
        }
        e.terminer();
      }
    }

    test(
      'la lecture redresse, sans relire ; annuler et le résultat suit',
      () async {
        final e = Encre();
        final lecteur = _Lecteur('1/3=');
        final calcul = CalculFeuille(
          encre: e,
          lecteur: lecteur,
          moteur: _Moteur(),
          pause: Duration.zero,
        );
        addTearDown(calcul.dispose);
        final vus = <(Trait, Trait)>[];
        e.surDeplacement = vus.addAll;
        ecrire(e, const [
          (0, 10, 0, 40),
          (10, 45, 30, 5),
          (40, 10, 40, 40),
          (60, 20, 80, 20),
          (60, 30, 80, 30),
        ]);
        calcul.encreChangee();
        // Jusqu'à la fin de la lecture (le tracé indulgent est tenté avant
        // le modèle, ADR 0050) : un délai fixe était fragile.
        for (var i = 0; i < 200; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          if (calcul.blocs.isNotEmpty &&
              calcul.blocs.single.etat != EtatBloc.lecture &&
              calcul.blocs.single.etat != EtatBloc.calcul) {
            break;
          }
        }

        final bloc = calcul.blocs.single;
        expect(bloc.latex, r'\frac{1}{3}=');
        expect(vus, hasLength(5));
        expect(
          lecteur.lectures,
          1,
          reason: 'les mêmes points : pas de relecture',
        );
        final barre = e.traits[1];
        expect(barre.points.first.y, barre.points.last.y);
        expect(bloc.cadre.bottom, greaterThan(40));
        // Le résultat garde la taille de l'écriture, pas celle de la fraction.
        expect(bloc.hauteurLigne, 40);
        expect(bloc.cadre.height, greaterThan(40));
        final relu = BlocCalcul.depuisJson(bloc.versJson());
        expect(relu.hauteurLigne, 40);

        final redresse = bloc.cadre;
        e.annuler();
        calcul.encreChangee();
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(e.traits[1].points.first.y, 45);
        expect(calcul.blocs.single.cadre, isNot(redresse));
        expect(lecteur.lectures, 1);
      },
    );

    test('raturer tout le calcul retire le bloc', () async {
      final e = Encre();
      final calcul = CalculFeuille(
        encre: e,
        lecteur: _Lecteur('5'),
        moteur: _Moteur(),
        pause: Duration.zero,
      );
      addTearDown(calcul.dispose);
      ecrire(e, const [(0, 10, 10, 40)]);
      calcul.encreChangee();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(calcul.blocs, hasLength(1));
      e.traits.toList().forEach((_) => e.effacer());
      calcul.encreChangee();
      expect(calcul.blocs, isEmpty);
    });
  });

  test('1/3 : le 1 monte, la barre se couche, le 3 descend', () {
    final (a, b, c) = (signe(0), barre(10), signe(40));
    final r = redresserFractions([a, b, c], '1/3')!;
    expect(r.latex, r'\frac{1}{3}');
    final (na, nb, nc) = (r.traits[a.id]!, r.traits[b.id]!, r.traits[c.id]!);
    final y = cadre(nb).center.dy;
    expect(cadre(nb).height, 0, reason: 'la barre est à plat');
    expect(y, 25, reason: 'à mi-hauteur de la barre écrite');
    expect(cadre(na).bottom, lessThan(y));
    expect(cadre(nc).top, greaterThan(y));
    expect(cadre(na).center.dx, closeTo(cadre(nc).center.dx, 1e-9));
    expect(cadre(na).center.dx, closeTo(cadre(nb).center.dx, 1e-9));
  });

  test('la lecture réelle du modèle : `1 / 3 =`, avec ses espaces', () {
    final (a, b, c, d) = (signe(0), barre(10), signe(40), signe(60));
    expect(
      redresserFractions([a, b, c, d], '1 / 3 =')!.latex,
      r'\frac{1}{3} =',
    );
    final (e, f, g, h) = (signe(0), signe(14), barre(24), signe(50));
    expect(redresserFractions([e, f, g, h], '1 2 / 5')!.latex, r'\frac{12}{5}');
  });

  test('l’identifiant reste, l’ancien trait n’est pas touché', () {
    final (a, b, c) = (signe(0), barre(10), signe(40));
    final avant = a.points.first.y;
    final r = redresserFractions([a, b, c], '1/3')!;
    expect(r.traits[a.id]!.id, a.id);
    expect(a.points.first.y, avant);
    expect(r.traits[a.id]!.points, hasLength(a.points.length));
  });

  test('ce qui suit se rapproche : le = reste près de la fraction', () {
    final (a, b, c, d) = (signe(0), barre(10), signe(40), signe(60));
    final r = redresserFractions([a, b, c, d], '1/3=')!;
    expect(r.latex, r'\frac{1}{3}=');
    expect(cadre(r.traits[d.id]!).left, lessThan(60));
    final droiteBarre = cadre(r.traits[b.id]!).right;
    expect(cadre(r.traits[d.id]!).left, greaterThanOrEqualTo(droiteBarre));
  });

  test('deux chiffres au numérateur, un signe à deux traits', () {
    final (a, b, s, c, d) = (
      signe(0),
      signe(14),
      barre(24),
      signe(50),
      // Le 4 en deux traits : ils se chevauchent en largeur.
      trait(49, 10, 51, 40),
    );
    final r = redresserFractions([a, b, s, c, d], '12/4')!;
    expect(r.latex, r'\frac{12}{4}');
    final y = cadre(r.traits[s.id]!).center.dy;
    expect(cadre(r.traits[a.id]!).bottom, lessThan(y));
    expect(cadre(r.traits[b.id]!).bottom, lessThan(y));
    expect(cadre(r.traits[c.id]!).top, greaterThan(y));
    expect(cadre(r.traits[d.id]!).top, greaterThan(y));
  });

  test('ce qui précède ne bouge pas', () {
    final (a, p, b, s, c) = (
      signe(0),
      signe(20),
      signe(40),
      barre(50),
      signe(80),
    );
    final r = redresserFractions([a, p, b, s, c], '2+1/3')!;
    expect(r.latex, r'2+\frac{1}{3}');
    expect(r.traits.containsKey(a.id), isFalse);
    expect(r.traits.containsKey(p.id), isFalse);
  });

  test('deux fractions', () {
    final t = [
      signe(0),
      barre(10),
      signe(40),
      signe(60),
      signe(80),
      barre(90),
      signe(120),
    ];
    final r = redresserFractions(t, '1/3+1/4')!;
    expect(r.latex, r'\frac{1}{3}+\frac{1}{4}');
    expect(r.traits, hasLength(t.length));
  });

  group('dans le doute, rien ne bouge', () {
    test('pas de barre dans la lecture', () {
      expect(redresserFractions([signe(0)], '1'), isNull);
      expect(redresserFractions([signe(0)], r'\frac{1}{3}'), isNull);
    });

    test('pas de trait qui ressemble à une barre', () {
      expect(
        redresserFractions([signe(0), signe(20), signe(40)], '1/3'),
        isNull,
      );
    });

    test('une barre sur un groupe entre parenthèses', () {
      final t = [signe(0), barre(10), signe(40)];
      expect(redresserFractions(t, '(x+1)/3'), isNull);
    });

    test('moins de signes que la lecture n’en annonce', () {
      final t = [signe(0), barre(10), signe(40)];
      expect(redresserFractions(t, '12/3'), isNull);
    });

    test('un nom de fonction n’est pas un numérateur', () {
      final t = [signe(0), barre(10), signe(40)];
      expect(redresserFractions(t, r'\sin/3'), isNull);
    });
  });

  test('la feuille déplace, prévient, et annuler remet tout', () {
    final e = Encre()..commencer(const PointEncre(0, 10, 1));
    final t = e.traits.single;
    final vu = <(Trait, Trait)>[];
    e.surDeplacement = vu.addAll;
    final nouveau = Trait.deplace(t, const [PointEncre(9, 9, 1)]);
    e.remplacer({t.id: nouveau});
    expect(vu.single.$2, same(nouveau));
    expect(e.traits.single.points.first.x, 9);
    e.annuler();
    expect(e.traits.single.points.first.x, 0);
  });
}
