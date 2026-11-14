import 'package:fikajiana/comprendre/etapes.dart';
import 'package:fikajiana/l10n/gen/app_localizations.dart';
import 'package:fikajiana/ui/calcul/panneau_etapes.dart';
import 'package:fikajiana/ui/ecriture_animee.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> monter(WidgetTester t, Future<List<Etape>?> etapes) async {
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: PanneauEtapes(etapes: etapes)),
      ),
    );
    await t.pump();
    await t.pump(const Duration(seconds: 5));
  }

  testWidgets('chaque étape : son numéro, sa raison, sa ligne écrite', (
    t,
  ) async {
    await monter(
      t,
      Future.value(const [
        Etape(RaisonEtape.depart, 'x+4=0'),
        Etape(RaisonEtape.isoler, 'x=-4'),
        Etape(RaisonEtape.conclusion, 'x=-4'),
      ]),
    );
    expect(find.text('Résolution pas à pas'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text("L'équation à résoudre."), findsOneWidget);
    expect(find.text('Conclusion.'), findsOneWidget);
    expect(find.byType(EcritureAnimee), findsNWidgets(3));
  });

  testWidgets('toutes les raisons ont leur phrase, fr et en', (t) async {
    for (final langue in AppLocalizations.supportedLocales) {
      final l10n = await AppLocalizations.delegate.load(langue);
      for (final r in RaisonEtape.values) {
        expect(phraseEtape(l10n, r), isNotEmpty);
      }
    }
  });

  testWidgets('pas d’étapes : on le dit, sans rien inventer', (t) async {
    await monter(t, Future.value());
    expect(find.textContaining("Pas d'étapes"), findsOneWidget);
    expect(find.byType(EcritureAnimee), findsNothing);
  });
}
