import 'package:fikajiana/a_propos/contact.dart';
import 'package:fikajiana/reglages/reglages.dart';
import 'package:fikajiana/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('À propos : le nom d’Antsa, son courriel et le dépôt s’ouvrent '
      'au toucher ; WhatsApp caché sans numéro', (t) async {
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.localesTestValue = [const Locale('fr')];
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearAllTestValues);
    final ouverts = <String>[];
    var repond = true;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('fikajiana/systeme'),
      (appel) async {
        if (appel.method != 'ouvrir') return null;
        ouverts.add((appel.arguments as Map)['lien'] as String);
        return repond;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('fikajiana/systeme'),
        null,
      ),
    );
    await t.pumpWidget(App(reglages: Reglages()));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Menu'));
    await t.pumpAndSettle();
    await t.tap(find.text('Réglages'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Code source'));
    await t.pumpAndSettle();

    expect(find.textContaining(Contact.nom), findsOneWidget);
    expect(find.text(Contact.courriel), findsOneWidget);
    // Rien ne s'ouvre tout seul.
    expect(ouverts, isEmpty);
    // Cibles d'au moins 48 dp.
    expect(
      t.getSize(find.widgetWithText(ListTile, 'Écrire un courriel')).height,
      greaterThanOrEqualTo(48),
    );

    await t.tap(find.text('Écrire un courriel'));
    await t.pumpAndSettle();
    await t.tap(find.text('Code source'));
    await t.pumpAndSettle();
    expect(ouverts, [
      'mailto:antsa.raniriamanjaka@univ-antananarivo.mg',
      'https://github.com/raantss18/Fikajiana',
    ]);

    // WhatsApp : le numéro d'Antsa, avec l'indicatif de Madagascar.
    expect(Contact.lienWhatsApp, 'https://wa.me/261334383882');
    await t.ensureVisible(find.text('WhatsApp'));
    await t.pumpAndSettle();
    expect(find.text('+261334383882'), findsOneWidget);
    await t.tap(find.text('WhatsApp'));
    await t.pumpAndSettle();
    expect(ouverts.last, 'https://wa.me/261334383882');
    ouverts.clear();

    // Sans app pour l'ouvrir, on le dit.
    repond = false;
    await t.tap(find.text('Code source'));
    await t.pumpAndSettle();
    expect(
      find.text("Aucune app de l'appareil ne sait l'ouvrir."),
      findsOneWidget,
    );
  });
}
