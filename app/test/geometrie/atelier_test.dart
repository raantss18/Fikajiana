import 'dart:io';

import 'package:fikajiana/geometrie/atelier.dart';
import 'package:fikajiana/geometrie/ecriture_geo.dart';
import 'package:fikajiana/ui/geometrie/ecran_geometrie.dart';
import 'package:fikajiana/ui/services.dart';
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

  test('parallèle : la droite puis le point', () {
    poser(OutilGeo.droite, [(0, 0), (4, 0)]);
    a.outil = OutilGeo.parallele;
    expect(a.toucher(2, 0.1, _t), isTrue);
    expect(a.choisis, hasLength(1));
    expect(a.toucher(2, 3, _t), isTrue);
    expect(a.choisis, isEmpty);
    final d = a.formes[a.figure.objets.last]! as DroiteGeo;
    expect(d.a * 0 + d.b * 3, closeTo(d.c, 1e-9));
  });

  test('parallèle : le point puis la droite, cela revient au même', () {
    poser(OutilGeo.droite, [(0, 0), (4, 0)]);
    poser(OutilGeo.parallele, [(2, 3), (3, 0.1)]);
    final d = a.formes[a.figure.objets.last]! as DroiteGeo;
    expect(d.b * 3, closeTo(d.c, 1e-9));
    expect(d.a.abs(), closeTo(0, 1e-9));
  });

  test('un point touché sur un objet y reste', () {
    poser(OutilGeo.cercle, [(0, 0), (2, 0)]);
    poser(OutilGeo.point, [(0, 2.1)]);
    final m = a.figure.objets.last;
    expect(a.figure.definition(m), isA<PointSur>());
    a
      ..outil = OutilGeo.deplacer
      ..deplacer(m, 9, 0);
    final p = a.formes[m]! as PointGeo;
    expect(p.x, closeTo(2, 1e-9));
  });

  test('un point touché sur un croisement devient l’intersection', () {
    poser(OutilGeo.droite, [(0, 0), (4, 0)]);
    poser(OutilGeo.droite, [(1, -3), (1, 3)]);
    poser(OutilGeo.point, [(1.1, 0.1)]);
    final i = a.figure.definition(a.figure.objets.last);
    expect(i, isA<Construite>());
    expect((i as Construite).genre, GenreConstruction.intersection1);
  });

  test('aimant : un point libre va sur le nœud voisin de la grille', () {
    a.reglerAimant(1, 0.1);
    poser(OutilGeo.point, [(2.05, 2.96)]);
    var p = a.formes[a.figure.objets.last]! as PointGeo;
    expect((p.x, p.y), (2, 3));
    poser(OutilGeo.point, [(5.4, 5.4)]);
    p = a.formes[a.figure.objets.last]! as PointGeo;
    expect((p.x, p.y), (5.4, 5.4));
    a.aimant = false;
    poser(OutilGeo.point, [(7.05, 7.05)]);
    p = a.formes[a.figure.objets.last]! as PointGeo;
    expect((p.x, p.y), (7.05, 7.05));
  });

  test('milieu d’un segment : le toucher suffit', () {
    poser(OutilGeo.segment, [(0, 0), (4, 0)]);
    poser(OutilGeo.milieu, [(1, 0.1)]);
    expect(a.formes[a.figure.objets.last], isA<PointGeo>());
    final m = a.formes[a.figure.objets.last]! as PointGeo;
    expect((m.x, m.y), (2, 0));
  });

  test('polygone : se ferme sur son premier point', () {
    poser(OutilGeo.polygone, [(0, 0), (4, 0), (4, 3), (0, 0)]);
    expect(a.choisis, isEmpty);
    final g = a.formes[a.figure.objets.last]! as PolygoneGeo;
    expect(g.aire, closeTo(6, 1e-9));
  });

  test('polygone : deux points ne se ferment pas', () {
    poser(OutilGeo.polygone, [(0, 0), (4, 0), (0, 0)]);
    expect(a.choisis, hasLength(2));
    expect(a.formes.values.whereType<PolygoneGeo>(), isEmpty);
  });

  test('polygone régulier : demande les côtés, crée les sommets', () {
    poser(OutilGeo.polygoneRegulier, [(0, 0), (2, 0)]);
    expect(a.nombreAttendu, NombreDemande.cotes);
    expect(a.toucher(9, 9, _t), isFalse);
    a.donnerValeur(4);
    expect(a.nombreAttendu, isNull);
    expect(a.choisis, isEmpty);
    expect(a.formes.values.whereType<PolygoneGeo>(), hasLength(1));
    // A, B, et les sommets 3 et 4.
    expect(a.formes.values.whereType<PointGeo>(), hasLength(4));
  });

  test('cercle de rayon : la valeur devient un nombre caché', () {
    poser(OutilGeo.cercleRayon, [(0, 0)]);
    a.donnerValeur(3);
    expect(a.curseurs, isEmpty);
    expect(a.nombres, hasLength(1));
    expect(
      (a.formes[a.figure.objets.last]! as CercleGeo).rayon,
      closeTo(3, 1e-9),
    );
  });

  test('renoncer au nombre : rien n’est construit', () {
    poser(OutilGeo.point, [(0, 0)]);
    poser(OutilGeo.rotation, [(0, 0), (1, 1)]);
    expect(a.nombreAttendu, NombreDemande.angle);
    a.renoncerAuNombre();
    expect(a.choisis, isEmpty);
    expect(a.formes.values.whereType<CercleGeo>(), isEmpty);
    expect(a.figure.objets, hasLength(2));
  });

  test('rotation d’après un curseur : suit le curseur', () {
    final n = a.ajouterCurseur(90);
    poser(OutilGeo.point, [(1, 0)]);
    poser(OutilGeo.rotation, [(1, 0), (0, 0)]);
    a.donnerNombre(n);
    var p = a.formes[a.figure.objets.last]! as PointGeo;
    expect(p.y, closeTo(1, 1e-9));
    a.fixerNombre(n, 180);
    p = a.formes[a.figure.objets.last]! as PointGeo;
    expect(p.x, closeTo(-1, 1e-9));
  });

  test('longueur : d’un segment, ou entre deux points', () {
    poser(OutilGeo.segment, [(0, 0), (3, 4)]);
    poser(OutilGeo.longueur, [(1.5, 2)]);
    expect(
      (a.formes[a.figure.objets.last]! as NombreGeo).valeur,
      closeTo(5, 1e-9),
    );
    poser(OutilGeo.longueur, [(0, 0), (3, 4)]);
    expect(
      (a.formes[a.figure.objets.last]! as NombreGeo).valeur,
      closeTo(5, 1e-9),
    );
  });

  test('tangente : deux depuis l’extérieur, une sur le cercle', () {
    poser(OutilGeo.cercle, [(0, 0), (2, 0)]);
    var avant = a.figure.objets.length;
    poser(OutilGeo.tangente, [(0, 2), (5, 0)]);
    // Le point nouveau et ses deux tangentes.
    expect(a.figure.objets.length, avant + 3);
    avant = a.figure.objets.length;
    poser(OutilGeo.tangente, [(0, 2), (2, 0)]);
    expect(a.figure.objets.length, avant + 1);
  });

  test('lieu : il faut un point sur objet pour le faire bouger', () {
    poser(OutilGeo.cercle, [(0, 0), (4, 0)]);
    poser(OutilGeo.point, [(0, 4)]);
    final m = a.figure.objets.last;
    poser(OutilGeo.milieu, [(0, 4), (6, 0)]);
    final i = a.figure.objets.last;
    a.outil = OutilGeo.lieu;
    final pi = a.formes[i]! as PointGeo;
    expect(a.toucher(pi.x, pi.y, 0.1), isTrue);
    expect(
      a.toucher(6, 0, 0.1),
      isFalse,
      reason: 'libre : ne peut être moteur',
    );
    expect(a.toucher(0, 4, 0.1), isTrue);
    expect(a.formes[a.figure.objets.last], isA<LieuGeo>());
    expect(a.figure.definition(a.figure.objets.last).parents, [i, m]);
  });

  test('relation : le constat se lit une fois', () {
    poser(OutilGeo.droite, [(0, 0), (4, 0)]);
    poser(OutilGeo.parallele, [(2, 0), (2, 3)]);
    poser(OutilGeo.relation, [(3, 0), (3, 3)]);
    final c = a.prendreConstat()!;
    expect(c.constats.single.relation, RelationGeo.paralleles);
    expect(c.constats.single.resiste, isTrue);
    expect(a.prendreConstat(), isNull);
  });

  test('un objet masqué ne se touche plus', () {
    poser(OutilGeo.droite, [(0, 0), (4, 0)]);
    final d = a.figure.objets.last;
    a.modifierApparence(d, (x) => x.visible = false);
    expect(a.objetProche(2, 0, _t), isNull);
  });

  test('aperçu : ce que donnerait le lever du doigt', () {
    a.outil = OutilGeo.segment;
    expect(a.apercu(1, 1), isNull);
    a.toucher(0, 0, _t);
    expect(a.apercu(1, 1), isA<DroiteGeo>());
    poser(OutilGeo.droite, [(5, 5), (6, 5)]);
    a
      ..outil = OutilGeo.parallele
      ..toucher(5.5, 5, _t);
    final d = a.apercu(0, 9)! as DroiteGeo;
    expect(d.b * 9, closeTo(d.c, 1e-9));
  });

  test('glisser d’un bloc : un seul pas à annuler', () {
    poser(OutilGeo.segment, [(0, 0), (4, 0)]);
    final s = a.figure.objets.last;
    a.outil = OutilGeo.deplacer;
    expect(a.objetAGlisser(2, 0, _t), s);
    a
      ..translater(s, 1, 0)
      ..translater(s, 1, 0)
      ..terminerGeste();
    expect((a.formes[0]! as PointGeo).x, 2);
    a.annuler();
    expect((a.formes[0]! as PointGeo).x, 0);
  });

  test('annuler et refaire ; un nouveau geste oublie ce qui suivait', () {
    poser(OutilGeo.point, [(1, 1)]);
    poser(OutilGeo.point, [(2, 2)]);
    a.annuler();
    expect(a.figure.objets, hasLength(1));
    expect(a.peutRetablir, isTrue);
    a.retablir();
    expect(a.figure.objets, hasLength(2));
    a.annuler();
    poser(OutilGeo.point, [(3, 3)]);
    expect(a.peutRetablir, isFalse);
  });

  test('effacer tout s’annule', () {
    poser(OutilGeo.point, [(1, 1)]);
    a.effacer();
    expect(a.estVide, isTrue);
    a.annuler();
    expect(a.figure.objets, hasLength(1));
  });

  test('renommer, doublon refusé', () {
    poser(OutilGeo.point, [(1, 1)]);
    poser(OutilGeo.point, [(2, 2)]);
    final ids = a.figure.objets.toList();
    expect(a.renommer(ids[1], 'M'), isTrue);
    expect(a.figure.nom(ids[1]), 'M');
    expect(a.renommer(ids[0], 'M'), isFalse);
  });

  test('curseur : bornes et valeur ramenée dedans', () {
    final n = a.ajouterCurseur(4);
    a.bornerCurseur(n, 0, 2);
    expect((a.formes[n]! as NombreGeo).valeur, 2);
    a.bornerCurseur(n, 3, 1);
    expect((a.figure.definition(n) as NombreLibre).max, 2);
  });

  test('changer de fichier : l’autre figure, sans annulation croisée', () {
    final dossier = Directory.systemTemp.createTempSync('figure');
    addTearDown(() => dossier.deleteSync(recursive: true));
    final (f1, f2) = (
      File('${dossier.path}/1.json'),
      File('${dossier.path}/2.json'),
    );
    final b = Atelier(fichier: f1)
      ..outil = OutilGeo.point
      ..toucher(1, 1, _t)
      ..changerDeFichier(f2);
    expect(b.estVide, isTrue);
    expect(b.peutAnnuler, isFalse);
    expect(f2.existsSync(), isFalse);
    b
      ..outil = OutilGeo.point
      ..toucher(2, 2, _t)
      ..changerDeFichier(f1);
    expect((b.formes.values.single! as PointGeo).x, 1);
  });

  test('une figure de la 0.3 se relit', () {
    final dossier = Directory.systemTemp.createTempSync('figure');
    addTearDown(() => dossier.deleteSync(recursive: true));
    final f = File('${dossier.path}/figure.json')
      ..writeAsStringSync(
        '[{"id":0,"t":"libre","x":1,"y":2},'
        '{"id":1,"t":"libre","x":3,"y":2},'
        '{"id":2,"t":"droite","p":[0,1]}]',
      );
    final b = Atelier(fichier: f);
    expect(b.figure.nom(2), '(AB)');
    expect(b.formes[2], isA<DroiteGeo>());
  });

  group('écrire les valeurs', () {
    String? e(FormeGeo f) => ecrireForme(f, francais: true);
    test('référence : point, droites, cercle, angle', () {
      expect(e(const PointGeo(2, 3.5)), '(2 ; 3,5)');
      expect(ecrireForme(const PointGeo(2, 3.5), francais: false), '(2, 3.5)');
      expect(
        e(DroiteGeo.par(const PointGeo(0, 1), const PointGeo(1, 3))!),
        'y = 2x + 1',
      );
      expect(
        e(DroiteGeo.par(const PointGeo(0, 1), const PointGeo(1, 0))!),
        'y = −x + 1',
      );
      expect(
        e(DroiteGeo.par(const PointGeo(3, 0), const PointGeo(3, 1))!),
        'x = 3',
      );
      expect(
        e(DroiteGeo.par(const PointGeo(0, 0), const PointGeo(1, 0))!),
        'y = 0',
      );
      expect(e(const CercleGeo(PointGeo(1, -2), 2)), '(x − 1)² + (y + 2)² = 4');
      expect(e(const CercleGeo(PointGeo(0, 0), 2)), 'x² + y² = 4');
      expect(e(const AngleGeo(45, PointGeo(0, 0), 0, 1)), '45°');
    });

    test('conique : équation réduite au premier coefficient', () {
      final k = ConiqueGeo.depuis([1, 0, 1, 0, 0, -4])!;
      expect(e(k), 'x² + y² − 4 = 0');
    });
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
    // Le dernier toucher a posé B et le segment : il s'annule d'un coup.
    a.annuler();
    expect(a.figure.objets, hasLength(1));
    a.effacer();
    expect(a.estVide, isTrue);
  });

  test('les points ont des noms dans l’ordre, sans compter les lignes', () {
    poser(OutilGeo.segment, [(0, 0), (4, 0)]);
    poser(OutilGeo.point, [(9, 9)]);
    final ids = a.figure.objets.toList();
    expect(a.figure.nom(ids[0]), 'A');
    expect(a.figure.nom(ids[1]), 'B');
    expect(a.figure.nom(ids[3]), 'C');
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
      await t.tap(find.text('Figure').last);
      await t.pumpAndSettle();
      expect(find.byType(EcranGeometrie), findsOneWidget);
    }

    Future<void> choisir(WidgetTester t, String nom) async {
      await t.tap(find.text('Outils'));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text(nom),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await t.ensureVisible(find.text(nom));
      await t.pumpAndSettle();
      await t.tap(find.text(nom));
      await t.pumpAndSettle();
    }

    testWidgets('construire un segment, puis le déformer', (t) async {
      await ouvrir(t);
      await choisir(t, 'Segment');
      expect(find.textContaining('Touche deux points'), findsOneWidget);
      await t.tapAt(const Offset(100, 300));
      await t.pump(const Duration(milliseconds: 400));
      await t.tapAt(const Offset(300, 300));
      await t.pump(const Duration(milliseconds: 400));
      await choisir(t, 'Déplacer');
      await t.dragFrom(const Offset(100, 300), const Offset(0, 100));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });

    testWidgets('chaque outil porte son nom en toutes lettres', (t) async {
      await ouvrir(t);
      await t.tap(find.text('Outils'));
      await t.pumpAndSettle();
      expect(find.text('Droite parallèle'), findsOneWidget);
      expect(find.text('Droite perpendiculaire'), findsOneWidget);
    });

    testWidgets('glisser construit, et laisse voir le résultat', (t) async {
      await ouvrir(t);
      await choisir(t, 'Segment');
      await t.dragFrom(const Offset(100, 400), const Offset(150, 0));
      await t.pumpAndSettle();
      final s = PorteeServices.de(t.element(find.byType(EcranGeometrie)));
      expect(s.atelier.formes.values.whereType<DroiteGeo>(), hasLength(1));
    });

    testWidgets('toucher un objet le montre, on peut le modifier', (t) async {
      await ouvrir(t);
      final s = PorteeServices.de(t.element(find.byType(EcranGeometrie)));
      s.atelier
        ..outil = OutilGeo.point
        ..toucher(0, 0, _t)
        ..outil = OutilGeo.deplacer;
      await t.pump();
      await t.tapAt(const Offset(200, 400));
      await t.pumpAndSettle();
      expect(find.textContaining('A : (0 ; 0)'), findsOneWidget);
      await t.tap(find.byTooltip('Modifier'));
      await t.pumpAndSettle();
      expect(find.text('Propriétés'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextField, 'A'), 'O');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      expect(s.atelier.figure.nom(0), 'O');
    });

    testWidgets('la liste des objets dit tout', (t) async {
      await ouvrir(t);
      final s = PorteeServices.de(t.element(find.byType(EcranGeometrie)));
      s.atelier
        ..outil = OutilGeo.droite
        ..toucher(0, 1, _t)
        ..toucher(1, 3, _t)
        ..outil = OutilGeo.deplacer;
      await t.pump();
      await t.tap(find.byTooltip('Objets'));
      await t.pumpAndSettle();
      expect(find.text('(AB) : y = 2x + 1'), findsOneWidget);
      expect(find.text('Droite : A, B'), findsOneWidget);
    });

    testWidgets('un outil qui veut un nombre le demande', (t) async {
      await ouvrir(t);
      await choisir(t, 'Cercle : centre et rayon');
      await t.tapAt(const Offset(200, 400));
      await t.pumpAndSettle();
      expect(find.text('Rayon'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'abc');
      await t.tap(find.text('Appliquer'));
      await t.pump();
      expect(find.textContaining('pas un nombre'), findsOneWidget);
      await t.enterText(find.byType(TextField), '2,5');
      await t.tap(find.text('Appliquer'));
      await t.pumpAndSettle();
      final s = PorteeServices.de(t.element(find.byType(EcranGeometrie)));
      final c = s.atelier.formes.values.whereType<CercleGeo>().single;
      expect(c.rayon, 2.5);
    });

    testWidgets('curseur : créé, réglé, animé, arrêté', (t) async {
      await ouvrir(t);
      await choisir(t, 'Curseur');
      await t.tap(find.text('Appliquer'));
      await t.pumpAndSettle();
      expect(find.byType(Slider), findsOneWidget);
      await t.tap(find.byTooltip('Animer'));
      await t.pump(const Duration(milliseconds: 500));
      await t.pump(const Duration(milliseconds: 500));
      await t.tap(find.byTooltip('Arrêter'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });

    testWidgets('relation : dit ce qui est vrai, et si cela résiste', (
      t,
    ) async {
      await ouvrir(t);
      final s = PorteeServices.de(t.element(find.byType(EcranGeometrie)));
      s.atelier
        ..outil = OutilGeo.droite
        ..toucher(-3, 0, _t)
        ..toucher(3, 0, _t)
        ..outil = OutilGeo.parallele
        ..toucher(1, 0, _t)
        ..toucher(0, 2, _t);
      await t.pump();
      await choisir(t, 'Relation');
      await t.tapAt(const Offset(240, 400));
      await t.pump(const Duration(milliseconds: 300));
      await t.tapAt(const Offset(300, 320));
      await t.pumpAndSettle();
      expect(find.textContaining('parallèles'), findsOneWidget);
      expect(find.textContaining('positions essayées'), findsOneWidget);
    });

    testWidgets('paysage de téléphone, cibles et libellés', (t) async {
      final semantique = t.ensureSemantics();
      await ouvrir(t, taille: const Size(800, 400));
      await t.tap(find.text('Outils'));
      await t.pumpAndSettle();
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      semantique.dispose();
    });
  });
}
