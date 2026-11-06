import 'package:fikajiana/encre/feuille_encre.dart';
import 'package:fikajiana/ui/calcul/ecran_feuille.dart';
import 'package:fikajiana/ui/graphe/ecran_graphe.dart';
import 'package:fikajiana/ui/navigation/page_destination.dart';
import 'package:fikajiana/ui/theme/marque.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/helpers.dart';

Future<void> _aller(
  WidgetTester t,
  String ecran, {
  String menu = 'Menu',
}) async {
  await t.tap(find.byTooltip(menu));
  await t.pumpAndSettle();
  await t.tap(find.text(ecran).last);
  await t.pumpAndSettle();
}

void main() {
  group('navigation', () {
    testWidgets('accueil : Feuille, sans retour', (t) async {
      await t.pumpFikajiana();
      expect(find.byType(EcranFeuille), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });

    for (final (nom, taille) in [
      ('téléphone en portrait', const Size(400, 800)),
      ('téléphone en paysage', const Size(800, 400)),
      ('tablette', const Size(1000, 700)),
    ]) {
      testWidgets('$nom : la feuille occupe tout l’écran', (t) async {
        await t.pumpFikajiana(taille: taille);
        expect(t.getSize(find.byType(FeuilleEncre)), taille);
        expect(find.byType(AppBar), findsNothing);
        expect(find.byType(NavigationBar), findsNothing);
        expect(find.byType(NavigationRail), findsNothing);
        expect(find.text('Graphe'), findsNothing);
      });
    }

    testWidgets("← revient à l'écran précédent, pas à l'accueil", (t) async {
      await t.pumpFikajiana();
      await _aller(t, 'Graphe');
      await _aller(t, 'Géométrie');
      expect(find.text('Géométrie'), findsOneWidget);

      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      expect(find.byType(EcranGraphe), findsOneWidget);
    });

    testWidgets('Feuille, dans le menu, revient directement à l’accueil', (
      t,
    ) async {
      await t.pumpFikajiana();
      await _aller(t, 'Graphe');
      await _aller(t, 'Historique');
      await _aller(t, 'Feuille');
      expect(find.byType(EcranFeuille), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('animations coupées : aucune transition', (t) async {
      await t.pumpFikajiana(sansAnimation: true);
      await t.tap(find.byTooltip('Menu'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      await t.tap(find.text('Graphe'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      final titre = find.text('Graphe');
      expect(
        find.ancestor(of: titre, matching: find.byType(SlideTransition)),
        findsNothing,
      );
    });
  });

  group('marque', () {
    testWidgets('le π est sur la Feuille, décoratif et sans libellé', (
      t,
    ) async {
      await t.pumpFikajiana();
      expect(find.byType(MarquePi), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MarquePi),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      await _aller(t, 'Graphe');
      expect(find.byType(MarquePi), findsNothing);
    });
  });

  group('langues', () {
    testWidgets('français', (t) async {
      await t.pumpFikajiana();
      await t.tap(find.byTooltip('Menu'));
      await t.pumpAndSettle();
      for (final s in ['Feuille', 'Graphe', 'Géométrie', 'Historique']) {
        expect(find.text(s), findsWidgets);
      }
      await t.tap(find.text('Géométrie'));
      await t.pumpAndSettle();
      expect(
        find.text("Cet écran n'est pas encore disponible."),
        findsOneWidget,
      );
    });

    testWidgets('anglais', (t) async {
      await t.pumpFikajiana(langue: const Locale('en'));
      await t.tap(find.byTooltip('Menu'));
      await t.pumpAndSettle();
      for (final s in ['Sheet', 'Graph', 'Geometry', 'History']) {
        expect(find.text(s), findsWidgets);
      }
      await t.tap(find.text('Geometry'));
      await t.pumpAndSettle();
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
        await _aller(t, 'Graphe');
        expect(find.byType(PageDestination), findsOneWidget);
        await expectLater(t, meetsGuideline(androidTapTargetGuideline));
        await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(t, meetsGuideline(textContrastGuideline));
        semantique.dispose();
      });
    }
  });
}
