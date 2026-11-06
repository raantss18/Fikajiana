import 'dart:io';

import 'package:fikajiana/comprendre/classeur.dart';
import 'package:fikajiana/ui/geometrie/ecran_geometrie.dart';
import 'package:fikajiana/ui/graphe/ecran_graphe.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/helpers.dart';

void main() {
  late Directory dossier;
  setUp(() => dossier = Directory.systemTemp.createTempSync('classeur'));
  tearDown(() => dossier.deleteSync(recursive: true));

  Directory sous() => Directory('${dossier.path}/figures');

  test('le document d’avant est repris, sans perte', () {
    final ancien = File('${dossier.path}/figure.json')
      ..writeAsStringSync('[1]');
    final c = Classeur(dossier: sous(), ancien: ancien);
    expect(ancien.existsSync(), isFalse);
    expect(c.fichier!.readAsStringSync(), '[1]');
    expect(c.apercus().single.contenu, [1]);
  });

  test('nouveau : l’ancien reste ; vide, on y reste', () {
    final c = Classeur(dossier: sous());
    final premier = c.courant;
    c.nouveau();
    expect(c.courant, premier, reason: 'rien écrit encore');
    c.fichier!.writeAsStringSync('[]');
    c.nouveau();
    expect(c.courant, isNot(premier));
    expect(c.apercus(), hasLength(1));
    c.ouvrir(premier);
    expect(c.fichier!.readAsStringSync(), '[]');
  });

  test('on retrouve le document courant au redémarrage', () {
    final c = Classeur(dossier: sous());
    c.fichier!.writeAsStringSync('[]');
    final premier = c.courant;
    c.nouveau();
    c.fichier!.writeAsStringSync('[2]');
    c.ouvrir(premier);
    expect(Classeur(dossier: sous()).courant, premier);
  });

  test('supprimer le courant passe au plus récent', () {
    final c = Classeur(dossier: sous());
    c.fichier!.writeAsStringSync('[]');
    final premier = c.courant;
    c.nouveau();
    c.fichier!.writeAsStringSync('[2]');
    c.supprimer(c.courant);
    expect(c.courant, premier);
    expect(c.apercus(), hasLength(1));
  });

  test('un fichier illisible reste, hors de la liste', () {
    final c = Classeur(dossier: sous());
    File('${sous().path}/abime.json').writeAsStringSync('{abîmé');
    expect(c.apercus(), isEmpty);
    expect(File('${sous().path}/abime.json').existsSync(), isTrue);
  });

  group('menu', () {
    Future<void> menu(WidgetTester t, String entree) async {
      await t.tap(find.byTooltip('Menu').last);
      await t.pumpAndSettle();
      await t.tap(find.text(entree));
      await t.pumpAndSettle();
    }

    testWidgets('propose les trois créations, et y mène', (t) async {
      await t.pumpFikajiana();
      await menu(t, 'Nouvelle figure');
      expect(find.byType(EcranGeometrie), findsOneWidget);
      await menu(t, 'Nouveau graphe');
      expect(find.byType(EcranGraphe), findsOneWidget);
      await menu(t, 'Nouvelle feuille');
      expect(find.byType(EcranGeometrie), findsNothing);
      expect(find.byType(EcranGraphe), findsNothing);
    });
  });
}
