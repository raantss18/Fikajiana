import 'dart:io';

import 'package:fikajiana/geometrie/atelier.dart';
import 'package:fikajiana/ui/geometrie/ecran_geometrie.dart';
import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/helpers.dart';

const double _t = 0.5;

void main() {
  late Atelier a;
  setUp(() => a = Atelier());

  void poser(OutilGeo outil, List<(double, double)> touchers) {
    a.outil = outil;
    for (final (x, y) in touchers) {
      a.toucher(x, y, _t);
    }
  }

  test('déplacer ne crée rien', () {
    expect(a.toucher(1, 1, _t), isFalse);
    expect(a.estVide, isTrue);
  });

  test('un segment crée ses deux points et les réutilise', () {
    poser(OutilGeo.segment, [(0, 0), (4, 0)]);
    expect(a.figure.objets, hasLength(3));
    poser(OutilGeo.segment, [(0.1, 0.1), (4, 3)]);
    // Le premier toucher reprend le point A.
    expect(a.figure.objets, hasLength(5));
  });

  test('parallèle : il faut toucher une droite, sinon rien', () {
    poser(OutilGeo.droite, [(0, 0), (4, 0)]);
    a.outil = OutilGeo.parallele;
    expect(a.toucher(9, 9, _t), isFalse);
    expect(a.toucher(2, 0.1, _t), isTrue);
    expect(a.choisis, hasLength(1));
    expect(a.toucher(2, 3, _t), isTrue);
    expect(a.choisis, isEmpty);
    final d = a.formes[a.figure.objets.last]! as DroiteGeo;
    expect(d.a * 0 + d.b * 3, closeTo(d.c, 1e-9));
  });

  test('intersection d’un cercle et d’une droite : deux points', () {
    poser(OutilGeo.cercle, [(0, 0), (2, 0)]);
    poser(OutilGeo.droite, [(-5, 1), (5, 1)]);
    final avant = a.figure.objets.length;
    poser(OutilGeo.intersection, [(0, 2), (3, 1)]);
    expect(a.figure.objets.length, avant + 2);
    expect(a.formes[a.figure.objets.last], isA<PointGeo>());
  });

  test('deux droites : un seul point', () {
    poser(OutilGeo.droite, [(0, 0), (4, 0)]);
    poser(OutilGeo.droite, [(1, -3), (1, 3)]);
    final avant = a.figure.objets.length;
    poser(OutilGeo.intersection, [(3, 0), (1, 2)]);
    expect(a.figure.objets.length, avant + 1);
  });

  test('un objet ne se coupe pas lui-même', () {
    poser(OutilGeo.droite, [(0, 0), (4, 0)]);
    final avant = a.figure.objets.length;
    poser(OutilGeo.intersection, [(2, 0), (3, 0)]);
    expect(a.figure.objets.length, avant);
  });

  test('un point libre attrapé déforme la figure', () {
    poser(OutilGeo.milieu, [(0, 0), (4, 0)]);
    a.outil = OutilGeo.deplacer;
    final id = a.pointLibreProche(0, 0, _t)!;
    a.deplacer(id, 4, 4);
    final m = a.formes[a.figure.objets.last]! as PointGeo;
    expect((m.x, m.y), (4, 2));
    expect(a.pointLibreProche(2, 2, _t), isNull);
  });

  test('la gomme emporte ce qui dépend de l’objet', () {
    poser(OutilGeo.milieu, [(0, 0), (4, 0)]);
    poser(OutilGeo.gomme, [(0, 0)]);
    expect(a.figure.objets, hasLength(1));
  });

  test('annuler, effacer', () {
    poser(OutilGeo.segment, [(0, 0), (4, 0)]);
    a.annuler();
    expect(a.figure.objets, hasLength(2));
    a.effacer();
    expect(a.estVide, isTrue);
  });

  test('les points ont des noms dans l’ordre, sans compter les lignes', () {
    poser(OutilGeo.segment, [(0, 0), (4, 0)]);
    poser(OutilGeo.point, [(9, 9)]);
    final ids = a.figure.objets.toList();
    expect(a.nomDuPoint(ids[0]), 'A');
    expect(a.nomDuPoint(ids[1]), 'B');
    expect(a.nomDuPoint(ids[3]), 'C');
  });

  test('une figure gardée ; fichier abîmé mis de côté', () {
    final dossier = Directory.systemTemp.createTempSync('figure');
    addTearDown(() => dossier.deleteSync(recursive: true));
    final fichier = File('${dossier.path}/figure.json');
    (Atelier(fichier: fichier)..outil = OutilGeo.point).toucher(1, 2, _t);
    expect(Atelier(fichier: fichier).figure.objets, hasLength(1));
    fichier.writeAsStringSync('{abîmé');
    expect(Atelier(fichier: fichier).estVide, isTrue);
    expect(File('${fichier.path}.illisible').existsSync(), isTrue);
  });

  group('distance', () {
    test('à un segment : l’extrémité au-delà de ses bouts', () {
      final s = DroiteGeo.par(
        const PointGeo(0, 0),
        const PointGeo(1, 0),
        segment: true,
      );
      expect(distanceA(s, 4, 0), closeTo(3, 1e-9));
      expect(distanceA(s, 0.5, 2), closeTo(2, 1e-9));
    });

    test('à un cercle', () {
      const c = CercleGeo(PointGeo(0, 0), 2);
      expect(distanceA(c, 5, 0), closeTo(3, 1e-9));
      expect(distanceA(null, 5, 0), double.infinity);
    });
  });

  group('écran', () {
    Future<void> ouvrir(
      WidgetTester t, {
      Size taille = const Size(400, 800),
    }) async {
      await t.pumpFikajiana(taille: taille);
      await t.tap(find.byTooltip('Menu'));
      await t.pumpAndSettle();
      await t.tap(find.text('Géométrie'));
      await t.pumpAndSettle();
      expect(find.byType(EcranGeometrie), findsOneWidget);
    }

    testWidgets('construire un segment, puis le déformer', (t) async {
      await ouvrir(t);
      await t.tap(find.byTooltip('Outils'));
      await t.pump();
      await t.tap(find.byTooltip('Segment'));
      await t.pump();
      await t.tapAt(const Offset(100, 300));
      await t.pump();
      await t.tapAt(const Offset(300, 300));
      await t.pump();
      await t.tap(find.byTooltip('Outils'));
      await t.pump();
      await t.tap(find.byTooltip('Déplacer'));
      await t.pump();
      await t.dragFrom(const Offset(100, 300), const Offset(0, 100));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.textContaining('Glisse un point'), findsOneWidget);
    });

    testWidgets('paysage de téléphone, cibles et libellés', (t) async {
      final semantique = t.ensureSemantics();
      await ouvrir(t, taille: const Size(800, 400));
      await t.tap(find.byTooltip('Outils'));
      await t.pump();
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      semantique.dispose();
    });
  });
}
