import 'dart:math' as math;

import 'package:fikajiana/encre/feuille_encre.dart';
import 'package:fikajiana/reglages/reglages.dart';
import 'package:fikajiana/reglages/support.dart';
import 'package:fikajiana/ui/app.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

double _contraste(Color a, Color b) {
  final (la, lb) = (a.computeLuminance(), b.computeLuminance());
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

Future<void> _monter(WidgetTester t, {Reglages? reglages}) async {
  t.view.physicalSize = const Size(1000, 700);
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.localesTestValue = [const Locale('fr')];
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearAllTestValues);
  await t.pumpWidget(App(reglages: reglages));
  await t.pumpAndSettle();
}

Future<void> _ecrireAuStylet(WidgetTester t) async {
  final centre = t.getCenter(find.byType(FeuilleEncre));
  final geste = await t.createGesture(kind: PointerDeviceKind.stylus);
  await geste.down(centre);
  await geste.moveBy(const Offset(40, 10));
  await geste.up();
  await t.pump();
}

void main() {
  group('supports', () {
    for (final support in SupportEcriture.values) {
      test('${support.name} : chaque stylo se lit sur le fond', () {
        for (final stylo in support.stylos) {
          final r = _contraste(stylo, support.fond);
          // ignore: avoid_print, relevé noté dans docs/design.md
          print(
            '${support.name} | ${stylo.toARGB32().toRadixString(16)} | '
            '${r.toStringAsFixed(2)}',
          );
          expect(r, greaterThanOrEqualTo(4.5));
        }
      });

      test('${support.name} : même nombre de stylos', () {
        expect(support.stylos.length, 4);
      });
    }

    test('le tableau noir est le seul support sombre', () {
      expect(SupportEcriture.values.where((s) => s.estSombre), [
        SupportEcriture.tableauNoir,
      ]);
    });
  });

  group('réglages', () {
    test('le choix survit à un redémarrage', () async {
      SharedPreferences.setMockInitialValues({});
      (await Reglages.charger())
        ..support = SupportEcriture.cahierPetitsCarreaux
        ..indiceStylo = 2;

      final relus = await Reglages.charger();
      expect(relus.support, SupportEcriture.cahierPetitsCarreaux);
      expect(relus.indiceStylo, 2);
    });

    test('une valeur inconnue revient au support par défaut', () async {
      SharedPreferences.setMockInitialValues({
        'support': 'ardoise',
        'stylo': 9,
      });
      final relus = await Reglages.charger();
      expect(relus.support, SupportEcriture.feuilleBlanche);
      expect(relus.indiceStylo, 3);
    });
  });

  group('écran', () {
    testWidgets('choisir le tableau noir passe toute l’app en sombre', (
      t,
    ) async {
      await _monter(t);
      await t.tap(find.byTooltip('Menu'));
      await t.pumpAndSettle();
      await t.tap(find.text('Réglages'));
      await t.pumpAndSettle();
      await t.tap(find.text('Tableau noir'));
      await t.pumpAndSettle();
      expect(
        Theme.of(t.element(find.text('Tableau noir'))).brightness,
        Brightness.dark,
      );

      await t.tap(find.text('Feuille blanche'));
      await t.pumpAndSettle();
      expect(
        Theme.of(t.element(find.text('Feuille blanche'))).brightness,
        Brightness.light,
      );
    });

    testWidgets('l’invitation disparaît au premier trait', (t) async {
      await _monter(t);
      expect(
        find.textContaining(
          'Écris ici. Deux doigts pour déplacer la page et zoomer.',
        ),
        findsOneWidget,
      );
      await _ecrireAuStylet(t);
      expect(
        find.textContaining(
          'Écris ici. Deux doigts pour déplacer la page et zoomer.',
        ),
        findsNothing,
      );
    });

    testWidgets('la gomme retire le trait, Annuler le rend', (t) async {
      await _monter(t);
      final etat = t.state<State<FeuilleEncre>>(find.byType(FeuilleEncre));
      final encre = etat.widget.encre;
      await _ecrireAuStylet(t);
      expect(encre.traits, hasLength(1));

      await t.tap(find.byTooltip('Outils'));
      await t.pump();
      await t.tap(find.text('Gomme'));
      await t.pump();
      await _ecrireAuStylet(t);
      expect(encre.estVide, isTrue);

      await t.tap(find.byTooltip('Outils'));
      await t.pump();
      await t.tap(find.text('Annuler'));
      await t.pump();
      expect(encre.traits, hasLength(1));
    });

    testWidgets('choisir un stylo quitte la gomme et colore le trait', (
      t,
    ) async {
      await _monter(t);
      final etat = t.state<State<FeuilleEncre>>(find.byType(FeuilleEncre));
      await t.tap(find.byTooltip('Outils'));
      await t.pump();
      await t.tap(find.text('Gomme'));
      await t.pump();
      await t.tap(find.byTooltip('Outils'));
      await t.pump();
      await t.tap(find.byTooltip('Stylo rouge'));
      await t.pump();
      await _ecrireAuStylet(t);
      expect(etat.widget.encre.traits.single.stylo, 2);
    });

    testWidgets('après le stylet, le doigt n’écrit plus', (t) async {
      await _monter(t);
      final etat = t.state<State<FeuilleEncre>>(find.byType(FeuilleEncre));
      await _ecrireAuStylet(t);
      await t.dragFrom(
        t.getCenter(find.byType(FeuilleEncre)),
        const Offset(50, 50),
      );
      await t.pump();
      expect(etat.widget.encre.traits, hasLength(1));
    });

    testWidgets('les outils sont repliés au départ', (t) async {
      await _monter(t);
      expect(find.text('Gomme'), findsNothing);
      await t.tap(find.byTooltip('Outils'));
      await t.pump();
      expect(find.text('Gomme'), findsOneWidget);
      await t.tap(find.byTooltip('Outils'));
      await t.pump();
      expect(find.text('Gomme'), findsNothing);
    });

    testWidgets('exact et degrés se basculent et se voient', (t) async {
      final reglages = Reglages();
      await _monter(t, reglages: reglages);
      await t.tap(find.byTooltip('Outils'));
      await t.pump();
      await t.ensureVisible(find.textContaining('Valeurs exactes'));
      await t.tap(find.textContaining('Valeurs exactes'));
      await t.pump();
      expect(reglages.approche, isTrue);
      expect(find.textContaining('Valeurs approchées'), findsOneWidget);
      await t.ensureVisible(find.textContaining('Angles en radians'));
      await t.pump();
      await t.tap(find.textContaining('Angles en radians'));
      await t.pump();
      expect(reglages.degres, isTrue);
      expect(find.textContaining('Angles en degrés'), findsOneWidget);
    });

    testWidgets('cibles et contrastes, tableau noir', (t) async {
      final semantique = t.ensureSemantics();
      await _monter(
        t,
        reglages: Reglages()..support = SupportEcriture.tableauNoir,
      );
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      await t.tap(find.byTooltip('Outils'));
      await t.pump();
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      semantique.dispose();
    });
  });
}
