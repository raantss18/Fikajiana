import 'package:fikajiana/comprendre/mots.dart';
import 'package:fikajiana/guide/catalogue.dart';
import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/ui/app.dart';
import 'package:fikajiana/ui/reglages/ecran_reglages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce qui se montre sans être une fonction de l'app : rien à y apprendre.
const _horsGuide = {
  'Voir les licences', 'View licences', // À propos.
  'Annuler', 'Cancel', // Fermer une fenêtre.
};

/// Les libellés d'un bouton à la forme « Valeurs exactes : toucher pour… »
/// se cherchent par leur début.
String _cherche(String libelle) => libelle.split(' : ').first.split(': ').first;

/// Les titres de liste et les boutons à libellé de l'écran affiché.
List<String> _libelles(WidgetTester t) => [
  for (final tuile in t.widgetList<ListTile>(find.byType(ListTile)))
    if (tuile.title case Text(:final data?)) data,
  for (final type in [FilledButton, OutlinedButton, TextButton])
    for (final e in find.byType(type).evaluate())
      for (final texte
          in find
              .descendant(
                of: find.byWidget(e.widget),
                matching: find.byType(Text),
              )
              .evaluate()
              .map((e) => (e.widget as Text).data))
        ?texte,
];

void _toutDansLeGuide(List<String> libelles, Locale langue) {
  final catalogue = catalogueGuide(lookupAppLocalizations(langue));
  final manquants = [
    for (final l in libelles.toSet())
      if (!_horsGuide.contains(l) &&
          chercherGuide(catalogue, _cherche(l)).isEmpty)
        l,
  ];
  expect(
    manquants,
    isEmpty,
    reason: 'Chaque fonction visible a son entrée dans le Guide (ADR 0045).',
  );
}

Future<void> _lancer(WidgetTester t, Locale langue) async {
  t.view.physicalSize = const Size(800, 2400);
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.localesTestValue = [langue];
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearAllTestValues);
  await t.pumpWidget(const App());
  await t.pumpAndSettle();
}

void main() {
  test('chaque commande écrite se trouve dans le Guide', () {
    final tout = [
      for (final langue in ['fr', 'en'])
        ...catalogueGuide(lookupAppLocalizations(Locale(langue))),
    ];
    for (final mot in motsDeCommande) {
      expect(chercherGuide(tout, mot), isNotEmpty, reason: mot);
    }
  });

  for (final langue in const [Locale('fr'), Locale('en')]) {
    final code = langue.languageCode;
    final l10n = lookupAppLocalizations(langue);

    testWidgets('chaque Outil de la Feuille est dans le Guide ($code)', (
      t,
    ) async {
      await _lancer(t, langue);
      await t.tap(find.byTooltip(l10n.outils).first);
      await t.pumpAndSettle();
      final libelles = _libelles(t);
      expect(libelles, contains(l10n.gomme));
      _toutDansLeGuide(libelles, langue);
    });

    testWidgets('chaque entrée du Menu est dans le Guide ($code)', (t) async {
      await _lancer(t, langue);
      await t.tap(find.byTooltip(l10n.menu));
      await t.pumpAndSettle();
      final libelles = _libelles(t);
      expect(libelles, contains(l10n.nouveauDocument));
      _toutDansLeGuide(libelles, langue);
    });

    testWidgets('chaque Réglage est dans le Guide ($code)', (t) async {
      await _lancer(t, langue);
      await t.tap(find.byTooltip(l10n.menu));
      await t.pumpAndSettle();
      await t.tap(find.text(l10n.reglages).last);
      await t.pumpAndSettle();
      expect(find.byType(EcranReglages), findsOneWidget);
      _toutDansLeGuide(_libelles(t), langue);
    });
  }
}
