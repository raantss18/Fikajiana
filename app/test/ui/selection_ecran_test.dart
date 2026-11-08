import 'package:fikajiana/ui/calcul/selection_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/helpers.dart';

void main() {
  Future<void> ecrire(WidgetTester t) async {
    final g = await t.startGesture(const Offset(150, 400));
    for (var i = 1; i <= 20; i++) {
      await g.moveTo(Offset(150 + i * 4.0, 400 + (i.isEven ? 3.0 : 0)));
    }
    await g.up();
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
  }

  Future<void> choisirUneLigne(WidgetTester t) async {
    await t.tap(find.byTooltip('Outils'));
    await t.pumpAndSettle();
    await t.tap(find.text('Choisir une ligne'));
    await t.pumpAndSettle();
  }

  testWidgets('choisir une ligne, la dupliquer, la supprimer, l’annuler', (
    t,
  ) async {
    await t.pumpFikajiana();
    await ecrire(t);
    await choisirUneLigne(t);
    expect(
      find.text('Touchez ou entourez une ligne pour la choisir.'),
      findsOneWidget,
    );
    expect(find.text('Dupliquer'), findsNothing);

    // Toucher l'écriture la choisit : elle s'entoure, la barre s'étend.
    await t.tapAt(const Offset(190, 402));
    await t.pumpAndSettle();
    expect(find.textContaining('Ligne choisie'), findsOneWidget);
    expect(find.bySemanticsLabel('Ligne choisie'), findsOneWidget);
    for (final nom in [
      'Monter',
      'Descendre',
      'Vers la gauche',
      'Vers la droite',
    ]) {
      expect(find.byTooltip(nom), findsOneWidget);
    }
    await expectLater(t, meetsGuideline(androidTapTargetGuideline));

    // Une flèche déplace sans geste : le cadre descend d'un pas.
    Rect cadre() => t.getRect(
      find.descendant(
        of: find.byType(CoucheSelection),
        matching: find.byType(DecoratedBox),
      ),
    );
    final avant = cadre();
    await t.tap(find.byTooltip('Descendre'));
    await t.pumpAndSettle();
    expect(cadre().top, closeTo(avant.top + pasSelection, 0.5));

    // Glisser la ligne choisie la porte.
    await t.dragFrom(cadre().center, const Offset(40, 0));
    await t.pumpAndSettle();
    expect(cadre().left, closeTo(avant.left + 40, 1));

    await t.tap(find.text('Dupliquer'));
    await t.pumpAndSettle();
    expect(find.text('Ligne dupliquée'), findsOneWidget);
    // La copie est choisie, dessous.
    expect(cadre().top, greaterThan(avant.bottom));

    await t.tap(find.text('Supprimer'));
    await t.pumpAndSettle();
    expect(find.text('Écriture effacée'), findsOneWidget);
    expect(
      find.text('Touchez ou entourez une ligne pour la choisir.'),
      findsOneWidget,
    );
    await t.tap(find.text('Annuler'));
    await t.pumpAndSettle();

    await t.tap(find.text('Terminer'));
    await t.pumpAndSettle();
    expect(find.byType(BarreSelection), findsNothing);
  });

  testWidgets('entourer une ligne la choisit', (t) async {
    await t.pumpFikajiana();
    await ecrire(t);
    await choisirUneLigne(t);
    final g = await t.startGesture(const Offset(120, 360));
    for (final p in const [
      Offset(260, 360),
      Offset(260, 440),
      Offset(120, 440),
      Offset(118, 365),
    ]) {
      await g.moveTo(p);
      await t.pump();
    }
    await g.up();
    await t.pumpAndSettle();
    expect(find.textContaining('Ligne choisie'), findsOneWidget);
  });

  testWidgets('entourer le vide ne choisit rien', (t) async {
    await t.pumpFikajiana();
    await ecrire(t);
    await choisirUneLigne(t);
    await t.dragFrom(const Offset(100, 600), const Offset(150, 50));
    await t.pumpAndSettle();
    expect(find.textContaining('Ligne choisie'), findsNothing);
  });

  testWidgets('← quitte le choix sans quitter la Feuille', (t) async {
    await t.pumpFikajiana();
    await ecrire(t);
    await choisirUneLigne(t);
    expect(find.byType(BarreSelection), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(BarreSelection), findsNothing);
  });
}
