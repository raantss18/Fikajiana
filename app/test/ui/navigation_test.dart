import 'package:fikajiana/ui/navigation/page_destination.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/helpers.dart';

Finder _titre(String texte) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(texte));

void main() {
  group('navigation', () {
    testWidgets('accueil : Feuille, ni retour ni bouton Accueil', (t) async {
      await t.pumpFikajiana();
      expect(_titre('Feuille'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      expect(find.byTooltip('Accueil'), findsNothing);
    });

    testWidgets("← revient à l'écran précédent, pas à l'accueil", (t) async {
      await t.pumpFikajiana();
      await t.tap(find.text('Graphe'));
      await t.pumpAndSettle();
      await t.tap(find.text('Géométrie'));
      await t.pumpAndSettle();
      expect(_titre('Géométrie'), findsOneWidget);

      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      expect(_titre('Graphe'), findsOneWidget);
    });

    testWidgets('Accueil revient directement à la Feuille', (t) async {
      await t.pumpFikajiana();
      await t.tap(find.text('Graphe'));
      await t.pumpAndSettle();
      await t.tap(find.text('Historique'));
      await t.pumpAndSettle();

      await t.tap(find.byTooltip('Accueil'));
      await t.pumpAndSettle();
      expect(_titre('Feuille'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('téléphone : barre du bas', (t) async {
      await t.pumpFikajiana();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('tablette : rail latéral', (t) async {
      await t.pumpFikajiana(taille: const Size(1000, 700));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      await t.tap(find.text('Graphe'));
      await t.pumpAndSettle();
      expect(_titre('Graphe'), findsOneWidget);
    });

    testWidgets('animations coupées : aucune transition', (t) async {
      await t.pumpFikajiana(sansAnimation: true);
      await t.tap(find.text('Graphe'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 1));
      expect(
        find.ancestor(
          of: _titre('Graphe'),
          matching: find.byType(SlideTransition),
        ),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: _titre('Graphe'),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );
    });
  });

  group('langues', () {
    testWidgets('français', (t) async {
      await t.pumpFikajiana();
      for (final s in ['Feuille', 'Graphe', 'Géométrie', 'Historique']) {
        expect(find.text(s), findsWidgets);
      }
      expect(
        find.text("Cet écran n'est pas encore disponible."),
        findsOneWidget,
      );
    });

    testWidgets('anglais', (t) async {
      await t.pumpFikajiana(langue: const Locale('en'));
      for (final s in ['Sheet', 'Graph', 'Geometry', 'History']) {
        expect(find.text(s), findsWidgets);
      }
      expect(find.text('This screen is not available yet.'), findsOneWidget);
    });
  });

  group('accessibilité', () {
    for (final (nom, taille) in [
      ('téléphone', const Size(400, 800)),
      ('tablette', const Size(1000, 700)),
    ]) {
      testWidgets('cibles et libellés, $nom', (t) async {
        final semantique = t.ensureSemantics();
        await t.pumpFikajiana(taille: taille);
        await t.tap(find.text('Graphe'));
        await t.pumpAndSettle();
        expect(find.byType(PageDestination), findsOneWidget);
        await expectLater(t, meetsGuideline(androidTapTargetGuideline));
        await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(t, meetsGuideline(textContrastGuideline));
        semantique.dispose();
      });
    }
  });
}
