import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:fikajiana/comprendre/signes.dart';
import 'package:fikajiana/comprendre/trace_ligne.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/reconnaissance/classeur_appris.dart';
import 'package:fikajiana/reconnaissance/classeur_signes.dart';
import 'package:fikajiana/reconnaissance/exemples_personnels.dart';
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
      final c = ClasseurAppris(exemples: ExemplesPersonnels());
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
    test('un signe corrigé se relit corrigé, la ligne aussi', () async {
      final exemples = ExemplesPersonnels();
      final c = ClasseurAppris(exemples: exemples);
      final detail = avecClasseur(c, () => lireAuTraceDetaille(ligne))!;
      expect(detail.latex, r'30\times8');
      expect(
        [for (final (_, s) in detail.signes) s],
        ['3', '0', r'\times', '8'],
      );
      await exemples.ajouter(detail.signes.last.$1, '3');
      c.oublier();
      expect(avecClasseur(c, () => lireAuTrace(ligne)), r'30\times3');
    });

    test('le même dessin ailleurs prend la classe apprise', () async {
      final exemples = ExemplesPersonnels();
      await exemples.ajouter(signes.last, 'B');
      final ailleurs = _copie(signes.last, 300);
      expect(exemples.corrige(ailleurs), isNull);
      expect(exemples.reconnaitre(ailleurs), 'B');
      final c = ClasseurAppris(exemples: exemples);
      expect(c.impose(ailleurs), 'B');
      final classes = await c.classer(
        ailleurs,
        caseLigne: const Rect.fromLTWH(0, 0, 100, 40),
      );
      expect(classes.first, ('B', 1.0));
    });

    test('deux exemples de classes différentes trop proches : doute', () async {
      final exemples = ExemplesPersonnels();
      await exemples.ajouter(signes.last, 'B');
      await exemples.ajouter(_copie(signes.last, 600), '8');
      expect(exemples.reconnaitre(_copie(signes.last, 300)), isNull);
    });

    test('restent sur l’appareil, et se rechargent', () async {
      final dossier = Directory.systemTemp.createTempSync('exemples');
      addTearDown(() => dossier.deleteSync(recursive: true));
      final fichier = File('${dossier.path}/signes/exemples.json');
      final exemples = ExemplesPersonnels(fichier: fichier);
      await exemples.ajouter(signes.first, '3');
      final relus = ExemplesPersonnels(fichier: fichier);
      await relus.charger();
      expect(relus.liste.single.classe, '3');
      expect(relus.corrige(signes.first), '3');
      await relus.toutEffacer();
      expect(relus.liste, isEmpty);
    });

    test('s’exportent au format de collecte/FORMAT.md', () async {
      final exemples = ExemplesPersonnels();
      await exemples.ajouter(signes.last, '3');
      await exemples.ajouter(signes[2], r'\times');
      await exemples.ajouter(signes.first, '§');
      final json = jsonDecode(
        exemples.exporter(
          modele: '2410CRP4CG',
          ecranDp: const Size(1280, 800),
          densite: 2.75,
        ),
      ) as Map<String, dynamic>;
      expect(json['format'], 1);
      expect(json['licence'], 'CC0-1.0');
      expect(json['appareil'], {
        'modele': '2410CRP4CG',
        'largeur_dp': 1280,
        'hauteur_dp': 800,
        'densite': 2.75,
      });
      expect(json['debut'], matches(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d[+-]'));
      final echantillons = (json['echantillons'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      // Le `§` n'est pas une classe de collecte/classes.txt.
      expect([for (final e in echantillons) e['classe']], ['3', 'fois']);
      final e = echantillons.first;
      expect(e['type'], 'signe');
      expect(e['attendu'], '3');
      expect(e['rejete'], isFalse);
      expect(e['case'], hasLength(4));
      final trait = (e['traits'] as List<dynamic>).first as List<dynamic>;
      final point = trait.first as List<dynamic>;
      expect(point, hasLength(4));
      expect(point[2], 0);
    });
  });
}
