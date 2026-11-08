import 'package:fikajiana/reglages/reglages.dart';
import 'package:fikajiana/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('premier lancement au format du Pad 7 : Continuer sans cocher '
      'laisse « non », jusque dans les Réglages', (tester) async {
    tester.view
      ..physicalSize = const Size(3200, 2136)
      ..devicePixelRatio = 2.75;
    tester.platformDispatcher.localesTestValue = [const Locale('fr')];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    SharedPreferences.setMockInitialValues({});
    final reglages = Reglages(stockage: await SharedPreferences.getInstance());
    await tester.pumpWidget(
      App(reglages: reglages, demanderConsentement: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('Continuer'), findsOneWidget);
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(reglages.donner, isFalse);
    expect(reglages.consentementDemande, isTrue);
    final relu = Reglages(stockage: await SharedPreferences.getInstance());
    expect(relu.donner, isFalse);
    expect(relu.consentementDemande, isTrue);
  });
}
