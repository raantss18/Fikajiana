import 'package:fikajiana/graphe/courbes.dart';
import 'package:fikajiana/l10n/gen/app_localizations.dart';
import 'package:fikajiana/ui/calcul/panneau_saisie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('le verbe dit ce qui va se passer', () {
    test('calculer, résoudre, tracer', () {
      expect(verbeDe('2+3'), isA<VerbeCalculer>());
      expect(verbeDe('2+3='), isA<VerbeCalculer>());
      expect(verbeDe('x^{2}=2'), isA<VerbeResoudre>());
      expect((verbeDe('t^{2}=2')! as VerbeResoudre).inconnue, 't');
      expect(verbeDe('f(x)=x^{2}'), isA<VerbeTracer>());
      expect(verbeDe('y=2x+1'), isA<VerbeTracer>());
      expect(verbeDe('x^{2}+y^{2}=9'), isA<VerbeTracer>());
      expect(verbeDe(r'\unknown'), isNull);
    });
  });

  test('une courbe tapée se trace', () {
    for (final texte in [
      r'\left(\cos\left(t\right),\sin\left(t\right)\right)',
    ]) {
      expect(lireCourbe(texte), isNotNull, reason: texte);
    }
  });

  group('le panneau', () {
    Future<void> ouvrir(
      WidgetTester t,
      void Function(String?) surFin, {
      String initial = '',
      String? action,
    }) async {
      await t.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  surFin(
                    await ouvrirPanneauSaisie(context, initial, action: action),
                  );
                },
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('ouvrir'));
      await t.pumpAndSettle();
    }

    FilledButton bouton(WidgetTester t) =>
        t.widget<FilledButton>(find.byType(FilledButton));

    testWidgets('dit Résoudre et rend le LaTeX', (t) async {
      String? rendu;
      await ouvrir(t, (l) => rendu = l);
      await t.enterText(find.byType(TextField), 'x^2+3x-5=0');
      await t.pump();
      expect(find.text('Résoudre en x'), findsOneWidget);
      await t.tap(find.text('Résoudre en x'));
      await t.pumpAndSettle();
      expect(rendu, 'x^{2}+3x-5=0');
    });

    testWidgets('dit Tracer pour une fonction', (t) async {
      await ouvrir(t, (_) {});
      await t.enterText(find.byType(TextField), 'y=2x+1');
      await t.pump();
      expect(find.text('Tracer'), findsOneWidget);
    });

    testWidgets('refuse un mot inconnu, et le dit', (t) async {
      await ouvrir(t, (_) {});
      await t.enterText(find.byType(TextField), 'hello');
      await t.pump();
      expect(find.textContaining('hello'), findsWidgets);
      expect(bouton(t).onPressed, isNull);
    });

    testWidgets('propose l’autre lecture de 1/2x', (t) async {
      String? rendu;
      await ouvrir(t, (l) => rendu = l);
      await t.enterText(find.byType(TextField), '1/2x');
      await t.pump();
      await t.tap(find.textContaining('1/(2x)'));
      await t.pump();
      await t.tap(find.byType(FilledButton));
      await t.pumpAndSettle();
      expect(rendu, r'\frac{1}{2x}');
    });

    testWidgets('une touche écrit et place le curseur', (t) async {
      String? rendu;
      await ouvrir(t, (l) => rendu = l);
      await t.tap(find.text('√'));
      await t.pump();
      expect(
        t.widget<TextField>(find.byType(TextField)).controller!.selection.start,
        5,
      );
      await t.enterText(find.byType(TextField), 'sqrt(2)');
      await t.pump();
      await t.tap(find.byType(FilledButton));
      await t.pumpAndSettle();
      expect(rendu, r'\sqrt{2}');
    });

    testWidgets('une lecture à corriger s’affiche en texte', (t) async {
      await ouvrir(t, (_) {}, initial: 'x ^ { 2 } = 2');
      expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text,
        'x^2=2',
      );
    });

    testWidgets('le nom imposé du bouton reste', (t) async {
      await ouvrir(t, (_) {}, action: 'Tracer');
      await t.enterText(find.byType(TextField), '2+3');
      await t.pump();
      expect(find.text('Tracer'), findsOneWidget);
    });
  });
}
