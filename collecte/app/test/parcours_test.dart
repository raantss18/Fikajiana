import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:collecte/app.dart';
import 'package:collecte/case_ecriture.dart';
import 'package:collecte/catalogue.dart';
import 'package:collecte/collecte.dart';
import 'package:collecte/depot.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';

import 'verifier_format.dart';

late Catalogue catalogue;

Future<Collecte> lancer(WidgetTester tester, DepotMemoire depot) async {
  tester.view
    ..physicalSize = const Size(1280, 800) * 2.75
    ..devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  final collecte = Collecte(
    depot: depot,
    catalogue: catalogue,
    hasard: Random(1),
  );
  await collecte.charger();
  await tester.pumpWidget(AppCollecte(collecte: collecte));
  return collecte;
}

var _pointeur = 100;

Future<void> ecrire(
  WidgetTester tester, {
  PointerDeviceKind outil = PointerDeviceKind.stylus,
}) async {
  final n = ++_pointeur;
  var p = tester.getCenter(find.byType(CaseEcriture));
  var t = const Duration(seconds: 10);
  tester.binding.handlePointerEvent(
    PointerDownEvent(
      pointer: n,
      kind: outil,
      position: p,
      pressure: 0.5,
      timeStamp: t,
    ),
  );
  for (var i = 0; i < 5; i++) {
    p += const Offset(8, 6);
    t += const Duration(milliseconds: 8);
    tester.binding.handlePointerEvent(
      PointerMoveEvent(
        pointer: n,
        kind: outil,
        position: p,
        pressure: 0.6,
        timeStamp: t,
      ),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }
  tester.binding.handlePointerEvent(
    PointerUpEvent(pointer: n, kind: outil, position: p, timeStamp: t),
  );
  await tester.pump();
}

Map<String, Object?> fichier(DepotMemoire depot) =>
    jsonDecode(depot.fichiers.values.single) as Map<String, Object?>;

List<Map<String, Object?>> echantillons(DepotMemoire depot) => [
  for (final e in fichier(depot)['echantillons']! as List<Object?>)
    e! as Map<String, Object?>,
];

void main() {
  setUpAll(() {
    catalogue = Catalogue(
      Catalogue.lireClasses(File('assets/classes.txt').readAsStringSync()),
      Catalogue.lireExpressions(
        File('assets/expressions.txt').readAsStringSync(),
      ),
    );
  });

  const total = '/ ${109 * 3}';

  testWidgets('premier lancement, puis une séance de signes', (tester) async {
    expect(catalogue.signes, hasLength(109));
    final depot = DepotMemoire();
    await lancer(tester, depot);
    expect(find.text('À quoi servent ces données'), findsOneWidget);
    expect(find.textContaining('CC0 1.0'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Antsa'), findsOneWidget);
    await tester.tap(find.text('J’ai compris, commencer'));
    await tester.pumpAndSettle();
    expect(find.text('Bonjour Antsa'), findsOneWidget);

    await tester.tap(find.textContaining('Nouvelle séance de signes'));
    await tester.pumpAndSettle();
    expect(find.text('1 $total'), findsOneWidget);
    // Rien d'écrit : Suivant ne fait rien.
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Suivant'))
          .onPressed,
      isNull,
    );

    await ecrire(tester);
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(find.text('2 $total'), findsOneWidget);
    final f = fichier(depot);
    expect(erreursFormat(f), isEmpty);
    expect(f['auteur'], 'Antsa');
    expect(f['outil'], 'stylet');
    final e = echantillons(depot).single;
    expect(e['rejete'], false);
    expect(e['type'], 'signe');
    final traits = e['traits']! as List<Object?>;
    final points = traits.single! as List<Object?>;
    expect(points, hasLength(6));
    expect((points.first! as List<Object?>)[2], 0);
    expect((points.first! as List<Object?>)[3], 0.5);
  });

  testWidgets('Effacer recommence, Raté garde à part et redemande', (
    tester,
  ) async {
    final depot = DepotMemoire()
      ..etat = jsonEncode({
        'reglages': {'accueilLu': true},
      });
    final collecte = await lancer(tester, depot);
    await tester.tap(find.textContaining('Nouvelle séance de signes'));
    await tester.pumpAndSettle();
    final premier = collecte.seance!.demande.classe;

    await ecrire(tester);
    await tester.tap(find.text('Effacer'));
    await tester.pump();
    expect(depot.fichiers, isEmpty);

    await ecrire(tester);
    await tester.tap(find.text('Raté'));
    await tester.pumpAndSettle();
    expect(find.text('1 $total'), findsOneWidget);
    expect(collecte.seance!.demande.classe, premier);
    expect(echantillons(depot).single['rejete'], true);
    expect(echantillons(depot).single['classe'], premier);
  });

  testWidgets('validation automatique après 1,2 s sans trait', (tester) async {
    final depot = DepotMemoire()
      ..etat = jsonEncode({
        'reglages': {'accueilLu': true},
      });
    await lancer(tester, depot);
    await tester.tap(find.textContaining('Nouvelle séance de signes'));
    await tester.pumpAndSettle();
    await ecrire(tester);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.text('1 $total'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('2 $total'), findsOneWidget);
  });

  testWidgets('après le stylet, la main posée n’écrit pas', (tester) async {
    final depot = DepotMemoire()
      ..etat = jsonEncode({
        'reglages': {'accueilLu': true, 'styletVu': true},
      });
    final collecte = await lancer(tester, depot);
    await tester.tap(find.textContaining('Nouvelle séance de signes'));
    await tester.pumpAndSettle();
    await ecrire(tester, outil: PointerDeviceKind.touch);
    expect(find.text('Effacer'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Suivant'))
          .onPressed,
      isNull,
    );
    // « Le doigt écrit » : le doigt écrit de nouveau.
    await collecte.changerReglages((r) => r.doigtEcrit = true);
    await tester.pump();
    await ecrire(tester, outil: PointerDeviceKind.touch);
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(fichier(depot)['outil'], 'doigt');
    expect(
      ((echantillons(depot).single['traits']! as List).first as List).first,
      [isA<num>(), isA<num>(), 0, 1],
    );
  });

  testWidgets('pause puis reprise là où la séance était', (tester) async {
    final depot = DepotMemoire()
      ..etat = jsonEncode({
        'reglages': {'accueilLu': true},
      });
    final premiere = await lancer(tester, depot);
    await tester.tap(find.textContaining('Nouvelle séance de signes'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await ecrire(tester);
      await tester.tap(find.text('Suivant'));
      await tester.pumpAndSettle();
    }
    final attendu = premiere.seance!.demande.classe;
    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();
    expect(find.text('Reprendre la séance de signes : 3 $total'), findsOne);

    // L'app est relancée : tout est relu depuis l'appareil.
    await tester.pumpWidget(const SizedBox());
    final seconde = await lancer(tester, depot);
    expect(find.text('Reprendre la séance de signes : 3 $total'), findsOne);
    await tester.tap(find.textContaining('Reprendre'));
    await tester.pumpAndSettle();
    expect(find.text('3 $total'), findsOneWidget);
    expect(seconde.seance!.demande.classe, attendu);
    await ecrire(tester);
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(echantillons(depot), hasLength(3));
  });

  testWidgets('expressions, puis Exporter ouvre le partage', (tester) async {
    final depot = DepotMemoire()
      ..etat = jsonEncode({
        'reglages': {'accueilLu': true, 'delaiMs': 0},
      });
    final collecte = await lancer(tester, depot);
    await tester.tap(find.textContaining('Nouvelle séance d’expressions'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 60'), findsOneWidget);
    expect(find.byType(Math), findsOneWidget);
    await ecrire(tester);
    // Sans validation automatique, rien ne part tout seul.
    await tester.pump(const Duration(seconds: 5));
    expect(depot.fichiers, isEmpty);
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    final e = echantillons(depot).single;
    expect(e['type'], 'expression');
    expect(e.containsKey('classe'), isFalse);
    expect(catalogue.expressions, contains(e['attendu']));

    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Exporter'));
    await tester.tap(find.text('Exporter'));
    await tester.pumpAndSettle();
    expect(depot.partages.single, [collecte.cheminSeance]);
    expect(find.textContaining('/memoire/seances'), findsOneWidget);
  });

  testWidgets('la fin de séance remercie et propose d’exporter', (
    tester,
  ) async {
    final depot = DepotMemoire()
      ..etat = jsonEncode({
        'reglages': {'accueilLu': true, 'repetitions': 1},
      });
    final collecte = await lancer(tester, depot);
    await tester.tap(find.textContaining('Nouvelle séance de signes'));
    await tester.pumpAndSettle();
    collecte.seance!.position = collecte.seance!.demandes.length - 1;
    await ecrire(tester);
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Merci ! La séance est enregistrée.'), findsOneWidget);
    expect(find.text('Exporter'), findsOneWidget);
  });

  testWidgets('téléphone en paysage : tout tient, cibles de 48 dp', (
    tester,
  ) async {
    final depot = DepotMemoire()
      ..etat = jsonEncode({
        'reglages': {'accueilLu': true},
      });
    await lancer(tester, depot);
    tester.view
      ..physicalSize = const Size(800, 360) * 3
      ..devicePixelRatio = 3;
    await tester.pump();
    await tester.tap(find.textContaining('Nouvelle séance de signes'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(CaseEcriture)).height, greaterThan(80));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });
}
