import 'package:fikajiana/ui/calcul/action_manuscrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> monter(WidgetTester t, Widget enfant) => t.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: enfant)),
    ),
  );

  // Antsa : pas de pastille imprimée sur la Feuille ; un mot écrit à la main,
  // qui garde son nom pour TalkBack et une cible de 48 dp (règle 9).
  testWidgets('« tracer » écrit à la main : se touche et se nomme', (t) async {
    var touche = 0;
    await monter(
      t,
      ActionManuscrite(
        mot: 'tracer',
        libelle: 'Tracer',
        surToucher: () => touche++,
      ),
    );
    expect(find.byType(FilledButton), findsNothing);
    expect(find.bySemanticsLabel('Tracer'), findsOneWidget);
    final taille = t.getSize(find.byType(ActionManuscrite));
    expect(taille.height, greaterThanOrEqualTo(48));
    expect(taille.width, greaterThanOrEqualTo(48));
    await t.tap(find.byType(ActionManuscrite));
    expect(touche, 1);
  });

  testWidgets('le crayon tracé : corriger, 48 dp', (t) async {
    var touche = 0;
    await monter(
      t,
      CrayonManuscrit(libelle: 'Corriger', surToucher: () => touche++),
    );
    expect(find.bySemanticsLabel('Corriger'), findsOneWidget);
    expect(t.getSize(find.byType(CrayonManuscrit)), const Size(48, 48));
    await t.tap(find.byType(CrayonManuscrit));
    expect(touche, 1);
  });
}
