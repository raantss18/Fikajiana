import 'package:fikajiana/comprendre/carnet.dart';
import 'package:fikajiana/comprendre/classeur.dart';
import 'package:fikajiana/geometrie/atelier.dart';
import 'package:fikajiana/graphe/courbes.dart';
import 'package:fikajiana/moteur/giac.dart';
import 'package:fikajiana/moteur/moteur.dart';
import 'package:fikajiana/reconnaissance/lecteur.dart';
import 'package:fikajiana/reconnaissance/modele.dart';
import 'package:fikajiana/ui/app.dart';
import 'package:fikajiana/ui/calcul/ecran_feuille.dart';
import 'package:fikajiana/ui/geometrie/ecran_geometrie.dart';
import 'package:fikajiana/ui/guide/ecran_guide.dart';
import 'package:fikajiana/ui/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Moteur implements Moteur {
  final entrees = <String>[];

  @override
  Future<ReponseGiac> calculer(String entree, {bool degres = false}) async {
    entrees.add(entree);
    return const ReponseGiac(exact: '6', latex: '6', approche: '6.0');
  }

  @override
  void interrompre() {}
}

Services _services(Moteur moteur) {
  final modele = ModeleOcr(dossier: null);
  return Services(
    modele: modele,
    lecteur: LecteurPix2Text(modele),
    moteur: moteur,
    courbes: Courbes(),
    atelier: Atelier(),
    carnet: Carnet(),
    graphes: Classeur(),
    figures: Classeur(),
  );
}

Future<void> _ouvrirGuide(
  WidgetTester t, {
  required Services services,
  Size taille = const Size(400, 800),
  Locale langue = const Locale('fr'),
}) async {
  t.view.physicalSize = taille;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.localesTestValue = [langue];
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearAllTestValues);
  await t.pumpWidget(App(services: services));
  await t.pumpAndSettle();
  await t.tap(find.byTooltip('Menu'));
  await t.pumpAndSettle();
  await t.tap(find.text('Guide').last);
  await t.pumpAndSettle();
}

Future<void> _chercher(WidgetTester t, String texte) async {
  await t.enterText(find.byType(TextField), texte);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('le menu ouvre le Guide, entre Historique et Réglages', (
    t,
  ) async {
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.localesTestValue = [const Locale('fr')];
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearAllTestValues);
    await t.pumpWidget(App(services: _services(_Moteur())));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Menu'));
    await t.pumpAndSettle();
    final y = [
      'Historique',
      'Guide',
      'Réglages',
    ].map((s) => t.getCenter(find.text(s).last).dy).toList();
    expect(y[0] < y[1] && y[1] < y[2], isTrue);
    await t.tap(find.text('Guide').last);
    await t.pumpAndSettle();
    expect(find.byType(EcranGuide), findsOneWidget);
  });

  testWidgets('la recherche filtre, sans accent ni casse', (t) async {
    await _ouvrirGuide(t, services: _services(_Moteur()));
    expect(find.byKey(const ValueKey('guide.operations')), findsOneWidget);

    await _chercher(t, 'ECART type');
    expect(find.byKey(const ValueKey('guide.ecartType')), findsOneWidget);
    expect(find.byKey(const ValueKey('guide.operations')), findsNothing);

    await _chercher(t, 'zzzqqq');
    expect(find.textContaining('Rien trouvé'), findsOneWidget);

    await t.tap(find.byTooltip('Effacer la recherche'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('guide.operations')), findsOneWidget);
  });

  testWidgets('Essayer pose la ligne sur la Feuille et y revient', (t) async {
    final moteur = _Moteur();
    await _ouvrirGuide(t, services: _services(moteur));
    await _chercher(t, 'pgcd');
    await t.tap(find.bySemanticsLabel('Essayer : PGCD'));
    await t.pumpAndSettle();

    expect(find.byType(EcranGuide), findsNothing);
    expect(find.byType(EcranFeuille), findsOneWidget);
    expect(moteur.entrees, contains('gcd(12,18)'));
  });

  testWidgets('Essayer un outil ouvre la Figure avec cet outil', (t) async {
    final services = _services(_Moteur());
    await _ouvrirGuide(t, services: services);
    await _chercher(t, 'cercle trois points');
    final carte = find.byKey(const ValueKey('guide.outil.cercleTroisPoints'));
    await t.tap(
      find.descendant(of: carte, matching: find.byType(FilledButton)),
    );
    await t.pumpAndSettle();

    expect(find.byType(EcranGeometrie), findsOneWidget);
    expect(services.atelier.outil, OutilGeo.cercleTroisPoints);
  });

  for (final (nom, taille) in [
    ('téléphone', const Size(360, 740)),
    ('tablette', const Size(800, 1280)),
    ('paysage', const Size(800, 360)),
  ]) {
    for (final langue in const [Locale('fr'), Locale('en')]) {
      testWidgets('$nom (${langue.languageCode}) : rien ne déborde', (t) async {
        await _ouvrirGuide(
          t,
          services: _services(_Moteur()),
          taille: taille,
          langue: langue,
        );
        // Tout le catalogue défile, sans erreur de mise en page, jusqu’aux
        // gestes, la dernière famille.
        final liste = find.byType(ListView);
        for (var i = 0; i < 80; i++) {
          await t.drag(liste, const Offset(0, -400));
          await t.pump();
        }
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.byKey(const ValueKey('guide.mainLevee')), findsOneWidget);
        // Les boutons Essayer font au moins 48 dp.
        for (final e in t.widgetList<FilledButton>(find.byType(FilledButton))) {
          expect(t.getSize(find.byWidget(e)).height, greaterThanOrEqualTo(48));
        }
        await expectLater(t, meetsGuideline(androidTapTargetGuideline));
        await expectLater(t, meetsGuideline(textContrastGuideline));
      });
    }
  }
}
