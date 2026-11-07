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

  group('un document : sa feuille et sa Figure (ADR 0032)', () {
    const annexes = ['graphes', 'figures'];
    File figureDe(String id) =>
        File('${dossier.path}/figures/$id.json')
          ..parent.createSync(recursive: true);
    File grapheDe(String id) =>
        File('${dossier.path}/graphes/$id.json')
          ..parent.createSync(recursive: true);

    test('la Figure compte dans le document, et dans l’Historique', () {
      final carnet = Carnet(dossier: dossier, annexes: annexes);
      _ecrire(carnet);
      figureDe(carnet.courante).writeAsStringSync(
        jsonEncode({
          'objets': [
            {'id': 0},
            {'id': 1},
          ],
        }),
      );
      grapheDe(carnet.courante).writeAsStringSync(jsonEncode(['y=x']));
      final apercu = carnet.apercus().single;
      expect(apercu.objets, 2);
      expect(apercu.courbes, ['y=x']);
    });

    test('une Figure seule fait un document : la nouvelle part de zéro', () {
      final carnet = Carnet(dossier: dossier, annexes: annexes);
      final premier = carnet.courante;
      figureDe(premier).writeAsStringSync(jsonEncode({'objets': <Object>[]}));
      // La feuille est vide, mais pas la Figure : c'est un vrai document.
      carnet.nouvelle();
      expect(carnet.courante, isNot(premier));
      expect(carnet.apercus().map((a) => a.id), contains(premier));
    });

    test('supprimer un document efface aussi sa Figure', () {
      final carnet = Carnet(dossier: dossier, annexes: annexes);
      _ecrire(carnet);
      final id = carnet.courante;
      figureDe(id).writeAsStringSync('{}');
      grapheDe(id).writeAsStringSync('[]');
      carnet.supprimer(id);
      expect(figureDe(id).existsSync(), isFalse);
      expect(grapheDe(id).existsSync(), isFalse);
    });

    void feuille(String id, List<String> lignes) =>
        File('${dossier.path}/feuilles/$id.json')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(
            jsonEncode({
              'traits': <Object>[],
              'blocs': [
                for (final l in lignes) {'latex': l},
              ],
            }),
          );

    // Le cas du Pad 7 : la figure et la courbe d'anciennes feuilles avaient
    // été rattachées à la feuille en cours.
    test('chaque Figure rejoint la feuille dont elle vient', () {
      feuille('100', ['A ( 1 ; 2 )', 'B ( 5 , - 4 )', 'cercle(A;3)']);
      feuille('200', ['f ( x ) = x ^ { 2 } - 1']);
      feuille('300', ['5 - 3 5 =']);
      File('${dossier.path}/documents.txt').writeAsStringSync('1');
      figureDe('300').writeAsStringSync(
        jsonEncode({
          'objets': [
            {
              'id': 0,
              't': 'libre',
              'x': 1.0,
              'y': 2.0,
              'a': {'n': 'A'},
            },
            {
              'id': 1,
              't': 'libre',
              'x': 5.0,
              'y': -4.0,
              'a': {'n': 'B'},
            },
          ],
        }),
      );
      grapheDe('300')
          .writeAsStringSync(jsonEncode(['f ( x ) = x ^ { 2 } - 1']));
      figureDe('400').writeAsStringSync('{"objets":[]}');
      rattacherFiguresAuxFeuilles(dossier, annexes);
      expect(figureDe('100').existsSync(), isTrue);
      expect(grapheDe('200').existsSync(), isTrue);
      expect(figureDe('300').existsSync(), isFalse);
      expect(grapheDe('300').existsSync(), isFalse);
      // Une figure qui ne ressemble à aucune feuille reste à part.
      expect(figureDe('400').existsSync(), isTrue);
      // Une seule fois.
      figureDe('300').writeAsStringSync(figureDe('100').readAsStringSync());
      rattacherFiguresAuxFeuilles(dossier, annexes);
      expect(figureDe('300').existsSync(), isTrue);
    });
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
      await t.tap(find.text('Nouveau document'));
      await t.pumpAndSettle();
      expect(find.byType(EcranHistorique), findsNothing);
      expect(find.byType(BackButton), findsNothing);
    });
  });
}
