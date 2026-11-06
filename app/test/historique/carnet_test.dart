import 'dart:convert';
import 'dart:io';

import 'package:fikajiana/comprendre/carnet.dart';
import 'package:fikajiana/ui/historique/ecran_historique.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/helpers.dart';

void _ecrire(Carnet carnet, {List<String> calculs = const ['2+3=']}) {
  (carnet.stockage!..programmer(
        () => {
          'traits': <Object>[],
          'blocs': [
            for (final latex in calculs) {'latex': latex},
          ],
        },
      ))
      .enregistrer();
}

void main() {
  late Directory dossier;
  setUp(() => dossier = Directory.systemTemp.createTempSync('carnet'));
  tearDown(() => dossier.deleteSync(recursive: true));

  test('la feuille de la 0.2.0 est reprise, et garde son contenu', () {
    File('${dossier.path}/feuille.json').writeAsStringSync(
      jsonEncode({
        'format': 1,
        'traits': <Object>[],
        'blocs': [
          {'latex': '1+1='},
        ],
      }),
    );
    final carnet = Carnet(dossier: dossier);
    expect(File('${dossier.path}/feuille.json').existsSync(), isFalse);
    expect(carnet.apercus().single.calculs, ['1+1=']);
    expect(carnet.apercus().single.id, carnet.courante);
    expect(carnet.stockage!.charger(), isNotNull);
  });

  test('une feuille neuve ; la vide n’est pas multipliée', () {
    final carnet = Carnet(dossier: dossier);
    final premiere = carnet.courante;
    carnet.nouvelle();
    expect(carnet.courante, premiere);
    _ecrire(carnet);
    carnet.nouvelle();
    expect(carnet.courante, isNot(premiere));
  });

  test('la feuille courante est retrouvée au redémarrage', () {
    final carnet = Carnet(dossier: dossier);
    _ecrire(carnet);
    final premiere = carnet.courante;
    carnet.nouvelle();
    _ecrire(carnet, calculs: ['x=1']);
    carnet.ouvrir(premiere);
    expect(Carnet(dossier: dossier).courante, premiere);
  });

  test('supprimer la courante passe à une autre', () {
    final carnet = Carnet(dossier: dossier);
    _ecrire(carnet);
    final premiere = carnet.courante;
    carnet.nouvelle();
    _ecrire(carnet);
    final seconde = carnet.courante;
    carnet.supprimer(seconde);
    expect(carnet.courante, premiere);
    expect(carnet.apercus(), hasLength(1));
    carnet.supprimer(premiere);
    expect(carnet.apercus(), isEmpty);
    expect(carnet.courante, isNot(premiere));
  });

  test('un fichier illisible reste en place, hors de la liste', () {
    final carnet = Carnet(dossier: dossier);
    _ecrire(carnet);
    final abime = File('${dossier.path}/feuilles/1.json')
      ..writeAsStringSync('{abîmé');
    expect(carnet.apercus(), hasLength(1));
    expect(abime.existsSync(), isTrue);
  });

  test('sans dossier : une feuille en mémoire, qu’on peut remplacer', () {
    final carnet = Carnet(horloge: () => DateTime(2026));
    final premiere = carnet.courante;
    expect(carnet.stockage, isNull);
    carnet.nouvelle();
    expect(carnet.courante, isNot(premiere));
  });

  group('écran', () {
    testWidgets('sans feuille : le dit ; nouvelle feuille revient', (t) async {
      await t.pumpFikajiana();
      await t.tap(find.byTooltip('Menu'));
      await t.pumpAndSettle();
      await t.tap(find.text('Historique'));
      await t.pumpAndSettle();
      expect(find.byType(EcranHistorique), findsOneWidget);
      expect(find.textContaining('Aucune feuille'), findsOneWidget);
      await t.tap(find.text('Nouvelle feuille'));
      await t.pumpAndSettle();
      expect(find.byType(EcranHistorique), findsNothing);
      expect(find.byType(BackButton), findsNothing);
    });
  });
}
