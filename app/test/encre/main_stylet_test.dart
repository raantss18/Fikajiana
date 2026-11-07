import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/encre/feuille_encre.dart';
import 'package:fikajiana/encre/vue_feuille.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Encre encre;
  late VueFeuille vue;
  late int stylets;

  Future<void> poser(WidgetTester t, {bool doigtDefile = false}) async {
    encre = Encre();
    vue = VueFeuille();
    stylets = 0;
    await t.pumpWidget(
      MaterialApp(
        home: FeuilleEncre(
          encre: encre,
          libelle: 'feuille',
          vue: vue,
          doigtDefile: doigtDefile,
          surStylet: () => stylets++,
        ),
      ),
    );
  }

  Future<TestGesture> poserDoigt(WidgetTester t, Offset ou, int id) =>
      t.startGesture(ou, pointer: id);

  Future<TestGesture> poserStylet(WidgetTester t, Offset ou, int id) =>
      t.startGesture(ou, pointer: id, kind: PointerDeviceKind.stylus);

  group('la main avec un stylet connu', () {
    testWidgets('fait défiler sans écrire, dès l’ouverture', (t) async {
      await poser(t, doigtDefile: true);
      final main = await poserDoigt(t, const Offset(100, 100), 1);
      await main.moveBy(const Offset(40, 30));
      await main.up();
      await t.pump();
      expect(encre.traits, isEmpty);
      expect(vue.decalage, const Offset(40, 30));
    });

    testWidgets('posée avant le stylet, ne bouge pas la page', (t) async {
      await poser(t, doigtDefile: true);
      final main = await poserDoigt(t, const Offset(300, 400), 1);
      final stylet = await poserStylet(t, const Offset(100, 100), 2);
      await stylet.moveBy(const Offset(30, 0));
      await main.moveBy(const Offset(50, 50));
      await stylet.up();
      await main.moveBy(const Offset(50, 50));
      await main.up();
      await t.pump();
      expect(encre.traits, hasLength(1));
      expect(vue.decalage, Offset.zero);
    });

    testWidgets('pendant que le stylet survole, ne défile pas', (t) async {
      await poser(t, doigtDefile: true);
      final survol = await t.createGesture(
        pointer: 3,
        kind: PointerDeviceKind.stylus,
      );
      await survol.addPointer(location: const Offset(100, 100));
      await survol.moveTo(const Offset(110, 100));
      final main = await poserDoigt(t, const Offset(300, 400), 1);
      await main.moveBy(const Offset(50, 50));
      await main.up();
      await survol.removePointer();
      await t.pump();
      expect(stylets, greaterThan(0));
      expect(vue.decalage, Offset.zero);
      expect(encre.traits, isEmpty);
    });
  });

  group('sans stylet connu', () {
    testWidgets('le doigt écrit', (t) async {
      await poser(t);
      final doigt = await poserDoigt(t, const Offset(100, 100), 1);
      await doigt.moveBy(const Offset(40, 30));
      await doigt.up();
      await t.pump();
      expect(encre.traits, hasLength(1));
      expect(stylets, 0);
    });

    testWidgets('le stylet efface le trait que la main commençait', (t) async {
      await poser(t);
      final main = await poserDoigt(t, const Offset(300, 400), 1);
      await main.moveBy(const Offset(10, 10));
      final stylet = await poserStylet(t, const Offset(100, 100), 2);
      await stylet.moveBy(const Offset(30, 0));
      await stylet.up();
      await main.up();
      await t.pump();
      expect(encre.traits, hasLength(1));
      expect(encre.traits.single.points.first.x, 100);
      expect(stylets, 1);
    });
  });
}
