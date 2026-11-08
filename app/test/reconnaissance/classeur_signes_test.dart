import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:fikajiana/comprendre/signes.dart';
import 'package:fikajiana/comprendre/trace_ligne.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/reconnaissance/classeur_appris.dart';
import 'package:fikajiana/reconnaissance/classeur_signes.dart';
import 'package:fikajiana/reconnaissance/ecritures.dart';
import 'package:flutter_test/flutter_test.dart';

List<Trait> _traits(String dossier, String nom) => [
  for (final t in jsonDecode(
    File('test/fixtures/$dossier/$nom.json').readAsStringSync(),
  ) as List<dynamic>)
    Trait.depuisDocument(t as Map<String, dynamic>),
];

/// Les mêmes traits, ailleurs sur la page, avec d'autres numéros.
List<Trait> _copie(List<Trait> signe, double dx) => [
  for (final t in signe)
    Trait.deplace(Trait(t.points.first), [
      for (final p in t.points)
        PointEncre(p.x + dx, p.y + 3, p.pression, tempsMs: p.tempsMs),
    ]),
];

void main() {
  final ligne = _traits('pad7', 'trente_fois_8');
  final signes = signesDeLaLigne(ligne);

  group('ClasseurGabarits (ADR 0041)', () {
    test('rend les verdicts des gabarits, tels quels', () {
      const c = ClasseurGabarits();
      for (final s in signes) {
        final dessin = dessinDe(s);
        expect(c.signe(s, hauteurLigne: 40), reconnaitreSigne(dessin));
        expect(c.chiffre(s), reconnaitreChiffre(dessin));
        expect(c.capitale(s), reconnaitreCapitale(dessin));
        expect(c.impose(s), isNull);
      }
    });

    test('classe du plus probable au moins probable', () async {
      final classes = await const ClasseurGabarits().classer(
        signes.last,
        caseLigne: const Rect.fromLTWH(0, 0, 100, 40),
      );
      expect(classes, hasLength(3));
      expect(classes.first.$1, '8');
      for (var i = 1; i < classes.length; i++) {
        expect(classes[i].$2, lessThanOrEqualTo(classes[i - 1].$2));
      }
      final total = classes.fold<double>(0, (s, c) => s + c.$2);
      expect(total, lessThanOrEqualTo(1 + 1e-9));
    });

    test('hors lecture, le classeur courant est celui des gabarits', () async {
      expect(classeurCourant, isA<ClasseurGabarits>());
      final appris = ClasseurAppris();
      await avecClasseur(appris, () async {
        await Future<void>.delayed(Duration.zero);
        expect(classeurCourant, same(appris));
      });
    });
  });

  group('ClasseurAppris', () {
    test('un signe déjà classé se relit dans le cache', () async {
      final c = ClasseurAppris();
      expect(
        await c.preparer(
          signes.last,
          caseLigne: const Rect.fromLTWH(0, 0, 100, 40),
        ),
        isTrue,
      );
      expect(c.connu(signes.last), isTrue);
      final avant = c.trouves;
      expect(c.signe(signes.last, hauteurLigne: 40), {
        '8': reconnaitreSigne(dessinDe(signes.last))!['8'],
      });
      expect(c.trouves, avant + 1);
    });

    test('lit la ligne comme les gabarits', () {
      final c = ClasseurAppris(ecritures: Ecritures());
      expect(avecClasseur(c, () => lireAuTrace(ligne)), lireAuTrace(ligne));
    });

    test('la règle de doute du modèle : seuil et écart au second', () {
      expect(ClasseurAppris.deciderProbas(const [('4', 0.97), ('1', 0.02)]), {
        '4': closeTo(0.03, 1e-9),
      });
      expect(
        ClasseurAppris.deciderProbas(const [('4', 0.6), ('1', 0.1)]),
        isNull,
      );
      expect(
        ClasseurAppris.deciderProbas(const [('4', 0.75), ('1', 0.5)]),
        isNull,
      );
      expect(ClasseurAppris.deciderProbas(const []), isNull);
    });
  });

  group('les corrections de la personne', () {
    const caseLigne = Rect.fromLTWH(0, 0, 100, 40);

    test('un signe corrigé se relit corrigé, la ligne aussi', () async {
      final ecritures = Ecritures();
      final c = ClasseurAppris(ecritures: ecritures);
      final detail = avecClasseur(c, () => lireAuTraceDetaille(ligne))!;
      expect(detail.latex, r'30\times8');
      expect(
        [for (final (_, s) in detail.signes) s],
        ['3', '0', r'\times', '8'],
      );
      await ecritures.corrigerSigne(
        detail.signes.last.$1,
        '3',
        caseLigne: caseLigne,
      );
      c.oublier();
      expect(avecClasseur(c, () => lireAuTrace(ligne)), r'30\times3');
    });

    test('le même dessin ailleurs prend la classe apprise', () async {
      final ecritures = Ecritures();
      await ecritures.corrigerSigne(signes.last, 'B', caseLigne: caseLigne);
      final ailleurs = _copie(signes.last, 300);
      expect(ecritures.corrige(ailleurs), isNull);
      expect(ecritures.reconnaitre(ailleurs), 'B');
      final c = ClasseurAppris(ecritures: ecritures);
      expect(c.impose(ailleurs), 'B');
      final classes = await c.classer(ailleurs, caseLigne: caseLigne);
      expect(classes.first, ('B', 1.0));
    });

    test(
      'deux corrections de classes différentes trop proches : doute',
      () async {
        final ecritures = Ecritures();
        await ecritures.corrigerSigne(signes.last, 'B', caseLigne: caseLigne);
        await ecritures.corrigerSigne(
          _copie(signes.last, 600),
          '8',
          caseLigne: caseLigne,
        );
        expect(ecritures.reconnaitre(_copie(signes.last, 300)), isNull);
      },
    );

    test('une lecture juste ne sert pas de correction', () async {
      final ecritures = Ecritures();
      await ecritures.jugerJuste(signes.last, '8', caseLigne, [
        (signes.last, '8', caseLigne),
      ]);
      expect(ecritures.corrige(signes.last), isNull);
      expect(ecritures.reconnaitre(_copie(signes.last, 300)), isNull);
    });
  });
}
