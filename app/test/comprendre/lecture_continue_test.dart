import 'dart:convert';
import 'dart:io';

import 'package:fikajiana/comprendre/calcul_feuille.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/l10n/gen/app_localizations.dart';
import 'package:fikajiana/moteur/giac.dart';
import 'package:fikajiana/moteur/moteur.dart';
import 'package:fikajiana/reconnaissance/lecteur.dart';
import 'package:fikajiana/ui/calcul/signes_lus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<dynamic> _document(String dossier, String nom) =>
    jsonDecode(File('test/fixtures/$dossier/$nom.json').readAsStringSync())
        as List<dynamic>;

class _Lecteur extends Lecteur {
  int lectures = 0;

  @override
  Future<String> lire(List<Trait> traits) async {
    lectures++;
    return r'\varLambda';
  }

  @override
  Future<List<String>> lirePlusieurs(List<Trait> traits) async => const [];
}

class _Moteur implements Moteur {
  @override
  Future<ReponseGiac> calculer(String entree, {bool degres = false}) async =>
      const ReponseGiac(exact: '240', latex: '240', approche: '240.0');

  @override
  void interrompre() {}
}

void main() {
  late Encre encre;
  late _Lecteur lecteur;

  setUp(() {
    encre = Encre()..chargerDocument(_document('pad7', 'trente_fois_8'));
    lecteur = _Lecteur();
  });

  group('lecture continue (ADR 0039)', () {
    test(
      'les signes tous lus : la ligne n’attend pas toute la pause',
      () async {
        final calcul = CalculFeuille(
          encre: encre,
          lecteur: lecteur,
          moteur: _Moteur(),
          pause: const Duration(seconds: 3),
          pauseConnue: const Duration(milliseconds: 300),
        );
        addTearDown(calcul.dispose);
        calcul.encreChangee();
        await Future<void>.delayed(const Duration(milliseconds: 900));
        expect(calcul.blocs.single.latex, r'30\times8');
        expect(lecteur.lectures, 0);
        expect(calcul.classeur.calcules, greaterThan(0));
      },
    );

    test('sans pause réduite, la pause entière reste', () async {
      final calcul = CalculFeuille(
        encre: encre,
        lecteur: lecteur,
        moteur: _Moteur(),
        pause: const Duration(seconds: 3),
        pauseConnue: const Duration(seconds: 3),
      );
      addTearDown(calcul.dispose);
      calcul.encreChangee();
      await Future<void>.delayed(const Duration(milliseconds: 900));
      expect(calcul.blocs, isEmpty);
    });

    test('toucher un signe, choisir : la ligne se relit corrigée', () async {
      final calcul = CalculFeuille(
        encre: encre,
        lecteur: lecteur,
        moteur: _Moteur(),
        pause: Duration.zero,
      );
      addTearDown(calcul.dispose);
      calcul.encreChangee();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final bloc = calcul.blocs.single;
      expect(bloc.signesLus, hasLength(4));
      final (huit, lu) = bloc.signesLus.last;
      expect(lu, '8');
      final autres = await calcul.autresSignes(bloc, huit);
      expect(autres.first.$1, '8');
      expect(autres, hasLength(3));
      await calcul.corrigerSigne(bloc, huit, '3');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(calcul.blocs.single.latex, r'30\times3');
      expect(calcul.classeur.exemples!.liste.single.classe, '3');
    });
  });

  testWidgets('les signes lus se touchent, une autre lecture se choisit', (
    tester,
  ) async {
    late CalculFeuille calcul;
    await tester.runAsync(() async {
      calcul = CalculFeuille(
        encre: encre,
        lecteur: lecteur,
        moteur: _Moteur(),
        pause: Duration.zero,
      )..encreChangee();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    addTearDown(calcul.dispose);
    final bloc = calcul.blocs.single;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => SignesLus(bloc: bloc, calcul: calcul),
                ),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    expect(find.text('Les signes lus'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(4));
    final cible = tester.getSize(find.byKey(const ValueKey('signe-lu-3')));
    expect(cible.height, greaterThanOrEqualTo(48));
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('signe-lu-3')));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('Ce signe peut aussi se lire :'), findsOneWidget);
    final autres = find.byType(ActionChip);
    expect(autres, findsWidgets);
    final premiere =
        tester.widget<ActionChip>(autres.first).key! as ValueKey<String>;
    await tester.runAsync(() async {
      await tester.tap(autres.first);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.text('Les signes lus'), findsNothing);
    final classe = premiere.value.replaceFirst('autre-signe-', '');
    expect(calcul.classeur.exemples!.liste.single.classe, classe);
  });
}
