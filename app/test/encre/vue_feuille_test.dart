import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/encre/feuille_encre.dart';
import 'package:fikajiana/encre/vue_feuille.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<(Encre, VueFeuille)> _monter(WidgetTester t) async {
  final encre = Encre();
  final vue = VueFeuille();
  addTearDown(vue.dispose);
  await t.pumpWidget(
    MaterialApp(
      home: FeuilleEncre(encre: encre, vue: vue, libelle: 'feuille'),
    ),
  );
  return (encre, vue);
}

void main() {
  group('VueFeuille', () {
    test('page et écran se correspondent', () {
      final vue = VueFeuille()
        ..glisser(const Offset(10, 20))
        ..zoomer(2, Offset.zero);
      // Zoom ×2 autour de l'origine : le décalage (10, 20) devient (20, 40).
      expect(vue.versPage(const Offset(50, 60)), const Offset(15, 10));
    });

    test('zoomer garde fixe le point sous le centre', () {
      final vue = VueFeuille()..glisser(const Offset(30, -40));
      const centre = Offset(200, 300);
      final avant = vue.versPage(centre);
      vue.zoomer(1.7, centre);
      expect(vue.versPage(centre).dx, closeTo(avant.dx, 1e-9));
      expect(vue.versPage(centre).dy, closeTo(avant.dy, 1e-9));
    });

    test('le zoom reste dans ses bornes', () {
      final vue = VueFeuille()..zoomer(100, Offset.zero);
      expect(vue.zoom, VueFeuille.zoomMax);
      vue.zoomer(0.001, Offset.zero);
      expect(vue.zoom, VueFeuille.zoomMin);
    });

    test('recentrer revient au départ', () {
      final vue = VueFeuille()
        ..glisser(const Offset(5, 5))
        ..zoomer(2, Offset.zero)
        ..recentrer();
      expect(vue.estInitiale, isTrue);
    });
  });

  group('gestes', () {
    testWidgets('au doigt seul, un doigt écrit', (t) async {
      final (encre, vue) = await _monter(t);
      await t.dragFrom(const Offset(100, 100), const Offset(50, 0));
      expect(encre.traits, hasLength(1));
      expect(vue.estInitiale, isTrue);
    });

    testWidgets('deux doigts déplacent et zooment, sans écrire', (t) async {
      final (encre, vue) = await _monter(t);
      final a = await t.startGesture(const Offset(100, 100));
      final b = await t.startGesture(const Offset(200, 100));
      await a.moveTo(const Offset(50, 100));
      await b.moveTo(const Offset(250, 100));
      await a.up();
      await b.up();
      expect(encre.estVide, isTrue);
      expect(encre.peutAnnuler, isFalse);
      expect(vue.zoom, greaterThan(1));
    });

    testWidgets('au stylet, le stylet écrit et un doigt déplace', (t) async {
      final (encre, vue) = await _monter(t);
      final stylet = await t.startGesture(
        const Offset(100, 100),
        kind: PointerDeviceKind.stylus,
      );
      await stylet.moveBy(const Offset(30, 0));
      await stylet.up();
      expect(encre.traits, hasLength(1));

      await t.dragFrom(const Offset(200, 200), const Offset(0, -80));
      expect(encre.traits, hasLength(1));
      expect(vue.decalage.dy, lessThan(0));
    });

    testWidgets('la paume posée pendant l’écriture ne bouge pas la page', (
      t,
    ) async {
      final (encre, vue) = await _monter(t);
      final stylet = await t.startGesture(
        const Offset(100, 100),
        kind: PointerDeviceKind.stylus,
      );
      final paume = await t.startGesture(const Offset(300, 300));
      await paume.moveBy(const Offset(40, 40));
      await stylet.moveBy(const Offset(30, 0));
      await paume.up();
      await stylet.up();
      expect(vue.estInitiale, isTrue);
      expect(encre.traits, hasLength(1));
    });

    testWidgets('un trait écrit après un zoom reste à sa place sur la page', (
      t,
    ) async {
      final (encre, vue) = await _monter(t);
      vue
        ..glisser(const Offset(10, 0))
        ..zoomer(2, Offset.zero);
      await t.pump();
      final stylet = await t.startGesture(
        const Offset(100, 100),
        kind: PointerDeviceKind.stylus,
      );
      await stylet.up();
      // Décalage (20, 0) après le zoom : (100 - 20) / 2 et 100 / 2.
      expect(encre.traits.single.points.first.position, const Offset(40, 50));
    });
  });
}
