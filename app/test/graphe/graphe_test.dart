import 'dart:io';

import 'package:fikajiana/geometrie/atelier.dart';
import 'package:fikajiana/graphe/courbes.dart';
import 'package:fikajiana/graphe/vue_graphe.dart';
import 'package:fikajiana/moteur/giac.dart';
import 'package:fikajiana/moteur/moteur.dart';
import 'package:fikajiana/reconnaissance/lecteur.dart';
import 'package:fikajiana/reconnaissance/modele.dart';
import 'package:fikajiana/ui/app.dart';
import 'package:fikajiana/ui/graphe/ecran_graphe.dart';
import 'package:fikajiana/ui/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/helpers.dart';

class _Moteur implements Moteur {
  @override
  Future<ReponseGiac> calculer(String entree, {bool degres = false}) async =>
      const ReponseGiac(exact: 'g', latex: 'g', approche: '');

  @override
  void interrompre() {}
}

void main() {
  group('lire une courbe', () {
    test('f(x)=…, y=… et une expression de x', () {
      expect(lireCourbe('f(x)=x^{2}')!.corps, '(x)^(2)');
      expect(lireCourbe('y=2x+1')!.corps, '2*x+1');
      expect(lireCourbe(r'\sin(x)')!.corps, 'sin(x)');
      expect(lireCourbe('g(t)=t+1')!.variable, 't');
    });

    test('ce qui ne se trace pas : null, rien de deviné', () {
      for (final latex in ['x^2=2', 'a+b', '(', 'x^2+y^2=1']) {
        expect(lireCourbe(latex), isNull, reason: latex);
      }
    });
  });

  group('liste', () {
    test('ajouter, éviter les doublons, retirer', () {
      final courbes = Courbes();
      expect(courbes.ajouter('y=x'), isTrue);
      expect(courbes.ajouter('f(x)=x'), isTrue);
      expect(courbes.liste, hasLength(1));
      expect(courbes.ajouter('x^2=2'), isFalse);
      courbes.retirer(0);
      expect(courbes.liste, isEmpty);
    });

    test('remplacer refuse ce qui ne se trace pas', () {
      final courbes = Courbes()..ajouter('y=x');
      expect(courbes.remplacer(0, 'a+b'), isFalse);
      expect(courbes.liste.single.corps, 'x');
      expect(courbes.remplacer(0, 'y=2x'), isTrue);
      expect(courbes.liste.single.corps, '2*x');
    });

    test('au-delà du maximum, la plus ancienne part', () {
      final courbes = Courbes();
      for (var i = 1; i <= Courbes.maximum + 1; i++) {
        courbes.ajouter('y=$i*x');
      }
      expect(courbes.liste, hasLength(Courbes.maximum));
      expect(courbes.liste.first.corps, '2*x');
    });

    test('gardées d’une fois sur l’autre ; fichier abîmé mis de côté', () {
      final dossier = Directory.systemTemp.createTempSync('courbes');
      addTearDown(() => dossier.deleteSync(recursive: true));
      final fichier = File('${dossier.path}/courbes.json');
      Courbes(fichier: fichier).ajouter('y=x');
      expect(Courbes(fichier: fichier).liste.single.latex, 'y=x');
      fichier.writeAsStringSync('{abîmé');
      expect(Courbes(fichier: fichier).liste, isEmpty);
      expect(File('${fichier.path}.illisible').existsSync(), isTrue);
    });
  });

  group('vue', () {
    const taille = Size(800, 400);

    test('aller-retour écran et maths', () {
      final vue = VueGraphe()..glisser(const Offset(30, -20));
      final p = vue.versEcran(1.5, -2, taille);
      final m = vue.versMaths(p, taille);
      expect(m.x, closeTo(1.5, 1e-9));
      expect(m.y, closeTo(-2, 1e-9));
    });

    test('le zoom garde le point touché en place', () {
      const point = Offset(600, 100);
      final vue = VueGraphe();
      final avant = vue.versMaths(point, taille);
      vue.zoomer(3, point, taille);
      final apres = vue.versMaths(point, taille);
      expect(apres.x, closeTo(avant.x, 1e-9));
      expect(apres.y, closeTo(avant.y, 1e-9));
    });

    test('la fenêtre couvre l’écran, axes à la même échelle', () {
      final f = VueGraphe().fenetre(taille);
      expect(f.xMax - f.xMin, closeTo(20, 1e-9));
      expect(f.yMax - f.yMin, closeTo(10, 1e-9));
    });

    test('recentrer', () {
      final vue = VueGraphe()
        ..glisser(const Offset(1, 1))
        ..zoomer(2, Offset.zero, taille);
      expect(vue.estInitiale, isFalse);
      vue.recentrer();
      expect(vue.estInitiale, isTrue);
    });
  });

  group('graduations', () {
    test('pas en 1, 2 ou 5 × 10ⁿ', () {
      expect(pasDeGraduation(64), 1);
      expect(pasDeGraduation(40), 2);
      expect(pasDeGraduation(20), 5);
      expect(pasDeGraduation(10), 10);
      expect(pasDeGraduation(640), closeTo(0.1, 1e-12));
    });

    test('nombres lisibles', () {
      expect(texteGraduation(0.1 + 0.2, 0.1, virgule: true), '0,3');
      expect(texteGraduation(-2, 1, virgule: false), '−2');
      expect(texteValeur(1.5, virgule: true), '1,5');
      expect(texteValeur(1e-12, virgule: true), '0');
    });
  });

  test('la courbe proche d’un point touché', () {
    const taille = Size(800, 400);
    final vue = VueGraphe();
    double f(double x) => x;
    double g(double x) => -x;
    final proche = courbeProche(
      [f, g],
      vue.versEcran(2, 2, taille),
      vue,
      taille,
    );
    expect(proche!.indice, 0);
    expect(proche.y, closeTo(2, 1e-9));
    expect(
      courbeProche([f], vue.versEcran(2, -8, taille), vue, taille),
      isNull,
    );
  });

  group('écran', () {
    Future<void> ouvrir(
      WidgetTester t, {
      Size taille = const Size(400, 800),
    }) async {
      await t.pumpFikajiana(taille: taille);
      await t.tap(find.byTooltip('Menu'));
      await t.pumpAndSettle();
      await t.tap(find.text('Graphe'));
      await t.pumpAndSettle();
      expect(find.byType(EcranGraphe), findsOneWidget);
    }

    Future<void> ajouter(WidgetTester t, String latex) async {
      await t.tap(find.byTooltip('Outils'));
      await t.pump();
      await t.tap(find.byTooltip('Ajouter une fonction'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), latex);
      await t.tap(find.widgetWithText(FilledButton, 'Tracer'));
      await t.pumpAndSettle();
    }

    testWidgets('ajouter, voir la légende, retirer', (t) async {
      await ouvrir(t);
      expect(find.textContaining('Aucune courbe'), findsOneWidget);
      await ajouter(t, 'y=x^2');
      expect(find.textContaining('Aucune courbe'), findsNothing);
      expect(find.text('1'), findsOneWidget);

      await t.tap(find.text('1'));
      await t.pumpAndSettle();
      await t.tap(find.text('Retirer'));
      await t.pumpAndSettle();
      expect(find.textContaining('Aucune courbe'), findsOneWidget);
    });

    testWidgets('une fonction de la feuille se trace d’un toucher', (t) async {
      t.view.physicalSize = const Size(400, 800);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.localesTestValue = [const Locale('fr')];
      addTearDown(t.view.reset);
      addTearDown(t.platformDispatcher.clearAllTestValues);
      final modele = ModeleOcr(dossier: null);
      await t.pumpWidget(
        App(
          services: Services(
            modele: modele,
            lecteur: LecteurPix2Text(modele),
            moteur: _Moteur(),
            courbes: Courbes(),
            atelier: Atelier(),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Outils'));
      await t.pump();
      await t.tap(find.byTooltip('Saisir au clavier'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'g(x)=x+1');
      await t.tap(find.widgetWithText(FilledButton, 'Calculer'));
      await t.pump();
      await t.pump();
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Tracer'));
      await t.pumpAndSettle();
      expect(find.byType(EcranGraphe), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('une expression non traçable est dite', (t) async {
      await ouvrir(t);
      await ajouter(t, 'a+b');
      expect(find.textContaining('ne se trace pas'), findsOneWidget);
    });

    testWidgets('paysage de téléphone, cibles et libellés', (t) async {
      final semantique = t.ensureSemantics();
      await ouvrir(t, taille: const Size(800, 400));
      await ajouter(t, r'\tan(x)');
      await t.tap(find.byTooltip('Outils'));
      await t.pump();
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      semantique.dispose();
    });

    testWidgets('glisser déplace, sans erreur de rendu', (t) async {
      await ouvrir(t);
      await ajouter(t, r'\frac{1}{x}');
      await t.dragFrom(const Offset(200, 500), const Offset(60, -40));
      await t.pumpAndSettle();
      await t.tapAt(const Offset(200, 500));
      await t.pump();
      expect(t.takeException(), isNull);
    });
  });
}
