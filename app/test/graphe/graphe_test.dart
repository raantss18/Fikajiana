import 'dart:io';

import 'package:fikajiana/comprendre/carnet.dart';
import 'package:fikajiana/comprendre/classeur.dart';
import 'package:fikajiana/geometrie/atelier.dart';
import 'package:fikajiana/graphe/courbes.dart';
import 'package:fikajiana/graphe/vue_graphe.dart';
import 'package:fikajiana/moteur/giac.dart';
import 'package:fikajiana/moteur/moteur.dart';
import 'package:fikajiana/reconnaissance/lecteur.dart';
import 'package:fikajiana/reconnaissance/modele.dart';
import 'package:fikajiana/ui/app.dart';
import 'package:fikajiana/ui/geometrie/ecran_geometrie.dart';
import 'package:fikajiana/ui/graphe/tableau_valeurs.dart';
import 'package:fikajiana/ui/services.dart';
import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      for (final latex in [
        'x^2=2',
        'a+b',
        '(',
        'x^2+y^2=z',
        r'(t,t),t\in[3,1]',
        'a,b,c',
      ]) {
        expect(lireCourbe(latex), isNull, reason: latex);
      }
    });
  });

  group('lire les autres courbes', () {
    test('implicite : équation en x et y, ou droite verticale', () {
      final c = lireCourbe('x^2+y^2=4')!;
      expect(c.genre, GenreCourbe.implicite);
      expect(c.corps, '((x)^(2)+(y)^(2))-(4)');
      expect(lireCourbe('x=3')!.genre, GenreCourbe.implicite);
      expect(lireCourbe('y^2=x')!.genre, GenreCourbe.implicite);
    });

    test('y=… reste une fonction', () {
      expect(lireCourbe('y=x^2')!.genre, GenreCourbe.fonction);
    });

    test('paramétrée : trois écritures', () {
      for (final latex in [
        r'(\cos(t),\sin(t))',
        r'\left(\cos(t),\sin(t)\right)',
        r'x=\cos(t),y=\sin(t)',
      ]) {
        final c = lireCourbe(latex);
        expect(c?.genre, GenreCourbe.parametree, reason: latex);
        expect(c!.corps, 'cos(t)');
        expect(c.corpsY, 'sin(t)');
        expect(c.variable, 't');
      }
    });

    test('polaire : r=… en θ', () {
      final c = lireCourbe(r'r=1+\cos(\theta)')!;
      expect(c.genre, GenreCourbe.polaire);
      expect(c.variable, 'theta');
      expect(lireCourbe(r'r(\theta)=2')!.genre, GenreCourbe.polaire);
    });

    test('domaine écrit après la courbe', () {
      final c = lireCourbe(r'(t,t^2),t\in[0,\pi]')!;
      expect(c.debut, 0);
      expect(c.fin, closeTo(3.14159265358979, 1e-12));
      final m = c.tracer(
        const Fenetre(
          xMin: -10,
          xMax: 10,
          yMin: -10,
          yMax: 10,
          largeurPixels: 800,
          hauteurPixels: 800,
        ),
        degres: false,
      );
      expect(m.single.first.x, 0);
      expect(m.single.last.x, closeTo(3.14159265358979, 1e-9));
    });

    // Valeur relevée avec SymPy 1.14 : (1 + cos(π/3)) cos(π/3), … en θ = π/3.
    test('cardioïde : passe par (0,75 ; 1,29904)', () {
      for (final degres in [false, true]) {
        final m = lireCourbe(r'r=1+\cos(\theta)')!.tracer(
          const Fenetre(
            xMin: -3,
            xMax: 3,
            yMin: -3,
            yMax: 3,
            largeurPixels: 600,
            hauteurPixels: 600,
          ),
          degres: degres,
        );
        final proche = m
            .expand((s) => s)
            .map((p) {
              final (dx, dy) = (p.x - 0.75, p.y - 1.29903810567666);
              return dx * dx + dy * dy;
            })
            .reduce((a, b) => a < b ? a : b);
        expect(proche, lessThan(0.001), reason: 'degres : $degres');
      }
    });

    test('doublon : même x(t), y(t) différent, deux courbes', () {
      final courbes = Courbes()
        ..ajouter('(t,t)')
        ..ajouter('(t,t^2)')
        ..ajouter('(t,t)');
      expect(courbes.liste, hasLength(2));
    });
  });

  group('tableau de valeurs', () {
    test('valeurs exactes, NaN hors du domaine, sans dérive', () {
      final l = calculerTableau(
        [compilerFonction('(x)^(2)'), compilerFonction('ln(x)')],
        -1,
        0.1,
      );
      expect(l, hasLength(lignesTableau));
      expect(l[0].y[0], closeTo(1, 1e-12));
      expect(l[0].y[1].isNaN, isTrue);
      expect(l[20].x, closeTo(1, 1e-12));
      expect(l[20].y[1], closeTo(0, 1e-12));
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
      await t.tap(find.text('Figure').last);
      await t.pumpAndSettle();
      expect(find.byType(EcranGeometrie), findsOneWidget);
    }

    Future<void> ajouter(WidgetTester t, String latex) async {
      await t.tap(find.text('Outils'));
      await t.pumpAndSettle();
      await t.tap(find.text('Ajouter une courbe'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), latex);
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'Tracer'));
      await t.pumpAndSettle();
    }

    testWidgets('ajouter, voir la légende, retirer', (t) async {
      await ouvrir(t);
      expect(find.textContaining('Touche Outils'), findsOneWidget);
      await ajouter(t, 'y=x^2');
      expect(find.textContaining('Touche Outils'), findsNothing);
      expect(find.text('1'), findsOneWidget);

      await t.tap(find.text('1'));
      await t.pumpAndSettle();
      await t.tap(find.text('Retirer'));
      await t.pumpAndSettle();
      expect(find.textContaining('Touche Outils'), findsOneWidget);
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
            carnet: Carnet(),
            graphes: Classeur(),
            figures: Classeur(),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Taper un calcul'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'g(x)=x+1');
      await t.pump();
      // Le bouton a dit Tracer : le graphique s'ouvre d'un coup.
      await t.tap(find.widgetWithText(FilledButton, 'Tracer'));
      await t.pumpAndSettle();
      expect(find.byType(EcranGeometrie), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('une équation en x et y se trace sans passer par Giac', (
      t,
    ) async {
      t.view.physicalSize = const Size(400, 800);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.localesTestValue = [const Locale('fr')];
      addTearDown(t.view.reset);
      addTearDown(t.platformDispatcher.clearAllTestValues);
      final modele = ModeleOcr(dossier: null);
      final courbes = Courbes();
      await t.pumpWidget(
        App(
          services: Services(
            modele: modele,
            lecteur: LecteurPix2Text(modele),
            moteur: _Moteur(),
            courbes: courbes,
            atelier: Atelier(),
            carnet: Carnet(),
            graphes: Classeur(),
            figures: Classeur(),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Taper un calcul'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'x^2+y^2=9');
      await t.pump();
      // Le nom se lit : ce n'est pas qu'un dessin de courbe.
      await t.tap(find.widgetWithText(FilledButton, 'Tracer'));
      await t.pumpAndSettle();
      expect(find.byType(EcranGeometrie), findsOneWidget);
      expect(courbes.liste.single.genre, GenreCourbe.implicite);
    });

    testWidgets('exporter en PNG passe la vraie image à Android', (t) async {
      await ouvrir(t);
      await ajouter(t, 'y=x');
      MethodCall? recu;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('fikajiana/systeme'),
        (appel) async {
          recu = appel;
          return true;
        },
      );
      await t.tap(find.text('Outils'));
      await t.pumpAndSettle();
      await t.dragUntilVisible(
        find.text('Exporter en image (PNG)'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Exporter en image (PNG)'));
      // Capture et encodage sont de vrais travaux asynchrones.
      for (var i = 0; i < 20 && recu == null; i++) {
        await t.pump(const Duration(milliseconds: 16));
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      final arguments = recu!.arguments as Map<Object?, Object?>;
      expect(recu!.method, 'enregistrer');
      expect(arguments['type'], 'image/png');
      expect(
        arguments['nom'],
        matches(r'^fikajiana-figure-\d{4}-\d\d-\d\d\.png$'),
      );
      // La signature du format PNG.
      expect((arguments['octets']! as Uint8List).sublist(0, 4), [
        0x89,
        0x50,
        0x4E,
        0x47,
      ]);
      await t.pumpAndSettle();
      expect(find.text('Enregistré'), findsOneWidget);
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
      await t.tap(find.text('Outils'));
      await t.pumpAndSettle();
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      semantique.dispose();
    });

    testWidgets('les quatre genres se tracent ; un toucher lit un point', (
      t,
    ) async {
      await ouvrir(t);
      for (final latex in [
        'x^2+y^2=4',
        r'(3\cos(t),\sin(t))',
        r'r=1+\cos(\theta)',
        'y=x',
      ]) {
        await ajouter(t, latex);
      }
      expect(t.takeException(), isNull);
      expect(find.text('4'), findsOneWidget);
      // Sur le cercle de rayon 2 : 80 pixels à droite du centre (200 ; 400).
      await t.tapAt(const Offset(280, 400));
      await t.pump();
      expect(t.takeException(), isNull);
    });

    testWidgets('tableau de valeurs : réglages, valeur non définie', (t) async {
      await ouvrir(t);
      await ajouter(t, r'\frac{1}{x}');
      await t.tap(find.text('Outils'));
      await t.pumpAndSettle();
      await t.dragUntilVisible(
        find.text('Tableau de valeurs'),
        find.byType(ListView),
        const Offset(0, -100),
      );
      await t.tap(find.text('Tableau de valeurs'));
      await t.pumpAndSettle();
      expect(find.text('−5'), findsOneWidget);
      expect(find.text('−0,2'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextField, '-5'), '0');
      await t.tap(find.text('Appliquer'));
      await t.pumpAndSettle();
      expect(find.text('non défini'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextField, '1'), '0');
      await t.tap(find.text('Appliquer'));
      await t.pump();
      expect(find.textContaining('pas non nul'), findsOneWidget);
    });

    testWidgets('sans fonction, le tableau le dit', (t) async {
      await ouvrir(t);
      await ajouter(t, 'x^2+y^2=4');
      await t.tap(find.text('Outils'));
      await t.pumpAndSettle();
      await t.dragUntilVisible(
        find.text('Tableau de valeurs'),
        find.byType(ListView),
        const Offset(0, -100),
      );
      await t.tap(find.text('Tableau de valeurs'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('Le tableau lit les fonctions'),
        findsOneWidget,
      );
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
