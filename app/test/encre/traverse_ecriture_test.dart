import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/encre/traverse_ecriture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('un bouton sur la feuille', () {
    Future<(List<Offset>, List<int>)> poser(WidgetTester t) async {
      final encre = <Offset>[];
      final touches = <int>[];
      await t.pumpWidget(
        MaterialApp(
          home: Stack(
            fit: StackFit.expand,
            children: [
              Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) => encre.add(e.localPosition),
                onPointerMove: (e) => encre.add(e.localPosition),
              ),
              Positioned(
                left: 100,
                top: 100,
                child: TraverseEcriture(
                  child: Material(
                    child: IconButton(
                      icon: const Icon(Icons.help_outline),
                      onPressed: () => touches.add(1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      return (encre, touches);
    }

    testWidgets('reçoit son toucher, et la feuille aussi', (t) async {
      final (encre, touches) = await poser(t);
      await t.tap(find.byType(IconButton));
      expect(touches, hasLength(1));
      expect(encre, hasLength(1));
    });

    testWidgets('un trait commencé dessus va à la feuille', (t) async {
      final (encre, touches) = await poser(t);
      final g = await t.startGesture(t.getCenter(find.byType(IconButton)));
      for (var i = 1; i <= 6; i++) {
        await g.moveBy(const Offset(15, 5));
      }
      await g.up();
      await t.pump();
      expect(encre, hasLength(7));
      expect(touches, isEmpty);
    });
  });

  group('retirer le point du toucher', () {
    void tracer(Encre e, List<Offset> points) {
      e.commencer(PointEncre(points.first.dx, points.first.dy, 1));
      for (final p in points.skip(1)) {
        e.prolonger(PointEncre(p.dx, p.dy, 1));
      }
      e.terminer();
    }

    test('le point part, sans étape à annuler', () {
      final e = Encre();
      tracer(e, const [Offset(10, 10), Offset(11, 10)]);
      e.retirerPointDuToucher();
      expect(e.traits, isEmpty);
      expect(e.peutAnnuler, isFalse);
    });

    test('un vrai trait reste', () {
      final e = Encre();
      tracer(e, const [Offset(10, 10), Offset(60, 10)]);
      e.retirerPointDuToucher();
      expect(e.traits, hasLength(1));
    });

    test('rien à faire sans trait', () {
      Encre().retirerPointDuToucher();
    });

    test('un point écrit plus tôt reste', () async {
      final e = Encre();
      tracer(e, const [Offset(10, 10), Offset(11, 10)]);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      e.retirerPointDuToucher();
      expect(e.traits, hasLength(1));
    });
  });
}
