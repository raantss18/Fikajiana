import 'package:fikajiana/ui/calcul/ecran_feuille.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/helpers.dart';

void main() {
  testWidgets('la rature propose Annuler, qui s’en va tout seul', (t) async {
    await t.pumpFikajiana();
    expect(find.byType(EcranFeuille), findsOneWidget);
    Future<void> tracer(List<Offset> points) async {
      final g = await t.startGesture(points.first);
      for (final p in points.skip(1)) {
        await g.moveTo(p);
      }
      await g.up();
      await t.pump();
    }

    await tracer([
      for (var i = 0; i <= 20; i++) Offset(150 + i.toDouble(), 300 + i * 2.0),
    ]);
    await tracer([
      for (var k = 0; k < 7; k++)
        for (var i = 0; i <= 8; i++)
          Offset(k.isEven ? 130 + i * 8.0 : 194 - i * 8.0, 290.0 + k * 9),
    ]);
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Effacé par la rature'), findsOneWidget);
    // Elle ne couvre pas le bouton Outils.
    final barre = t.getRect(
      find
          .descendant(
            of: find.byType(SnackBar),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(barre.right, lessThanOrEqualTo(400 - 64));
    await t.pump(const Duration(seconds: 5));
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
    expect(find.text('Effacé par la rature'), findsNothing);
  });
}
