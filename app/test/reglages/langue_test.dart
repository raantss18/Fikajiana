import 'package:fikajiana/reglages/reglages.dart';
import 'package:fikajiana/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'la langue choisie survit à un redémarrage ; le système l’efface',
    () async {
      SharedPreferences.setMockInitialValues({});
      (await Reglages.charger()).langue = 'en';
      expect((await Reglages.charger()).langue, 'en');
      (await Reglages.charger()).langue = null;
      expect((await Reglages.charger()).langue, isNull);
    },
  );

  test('une langue inconnue revient au système', () async {
    SharedPreferences.setMockInitialValues({'langue': 'mg'});
    expect((await Reglages.charger()).langue, isNull);
    final reglages = Reglages()..langue = 'de';
    expect(reglages.langue, isNull);
  });

  testWidgets('English puis le système : l’app change sans redémarrer', (
    t,
  ) async {
    t.view.physicalSize = const Size(800, 1600);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.localesTestValue = [const Locale('fr')];
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearAllTestValues);
    final reglages = Reglages();
    await t.pumpWidget(App(reglages: reglages));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Menu'));
    await t.pumpAndSettle();
    await t.tap(find.text('Réglages'));
    await t.pumpAndSettle();
    expect(find.text('Langue'), findsOneWidget);

    await t.tap(find.text('English'));
    await t.pumpAndSettle();
    expect(reglages.langue, 'en');
    // Le même écran, en anglais, sans le quitter.
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await t.tap(find.text('System language'));
    await t.pumpAndSettle();
    expect(reglages.langue, isNull);
    expect(find.text('Langue'), findsOneWidget);

    await t.tap(find.text('English'));
    await t.pumpAndSettle();
    await t.tap(find.text('Français'));
    await t.pumpAndSettle();
    expect(reglages.langue, 'fr');
    expect(find.text('Réglages'), findsOneWidget);
  });
}
