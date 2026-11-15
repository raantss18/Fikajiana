import 'package:fikajiana/comprendre/copie.dart';
import 'package:fikajiana/comprendre/fautes.dart';
import 'package:fikajiana/l10n/gen/app_localizations.dart';
import 'package:fikajiana/ui/calcul/panneau_copie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const copie = [
    LigneCopie('2x+3=7', '(2*x+3)=(7)', 'x'),
    LigneCopie('2x=10', '(2*x)=(10)', 'x'),
    LigneCopie('x=5', '(x)=(5)', 'x'),
  ];

  Future<void> monter(WidgetTester t, List<VerdictLigne> verdicts) async {
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PanneauCopie(copie: copie, verdicts: Future.value(verdicts)),
        ),
      ),
    );
    await t.pump();
    await t.pump(const Duration(seconds: 3));
  }

  testWidgets('la ligne fausse : une icône, une phrase, et le bilan', (
    t,
  ) async {
    await monter(t, const [
      VerdictLigne.depart,
      VerdictLigne.fausse,
      VerdictLigne.juste,
    ]);
    // Jamais la couleur seule : une forme et une phrase par verdict.
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.textContaining('À revoir'), findsOneWidget);
    expect(find.text('Une ligne à revoir.'), findsOneWidget);
  });

  testWidgets('tout juste : bravo', (t) async {
    await monter(t, const [
      VerdictLigne.depart,
      VerdictLigne.juste,
      VerdictLigne.juste,
    ]);
    expect(find.textContaining('Bravo'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });

  testWidgets('pas su comparer : ni bravo ni faute', (t) async {
    await monter(t, const [
      VerdictLigne.depart,
      VerdictLigne.inconnue,
      VerdictLigne.juste,
    ]);
    expect(find.textContaining('Bravo'), findsNothing);
    expect(find.textContaining('pas su comparer'), findsOneWidget);
  });

  testWidgets('Où est ma faute ? La piste et la ligne juste en marge', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PanneauCopie(
            copie: copie,
            verdicts: Future.value(const [
              VerdictLigne.depart,
              VerdictLigne.fausse,
              VerdictLigne.juste,
            ]),
            pistes: Future.value(const [
              null,
              PisteFaute(Faute.deplacementSansSigne, '2x=4'),
              null,
            ]),
          ),
        ),
      ),
    );
    await t.pump();
    await t.pump(const Duration(seconds: 3));
    expect(find.textContaining('sans changer de signe'), findsOneWidget);
    // La ligne juste attend qu'on la demande.
    expect(find.text('Il fallait :'), findsNothing);
    await t.tap(find.text('Voir la ligne juste'));
    await t.pump();
    expect(find.text('Il fallait :'), findsOneWidget);
  });

  testWidgets('chaque faute a sa phrase, en français et en anglais', (t) async {
    for (final langue in ['fr', 'en']) {
      final l10n = await AppLocalizations.delegate.load(Locale(langue));
      for (final f in Faute.values) {
        expect(phraseFaute(l10n, f), isNotEmpty, reason: '$langue ${f.name}');
      }
    }
  });
}
