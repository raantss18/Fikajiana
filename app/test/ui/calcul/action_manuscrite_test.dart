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

  // Vu sur le Pad 7 : `A=[1,2;3,4]` tapée ne s'affichait plus du tout.
  testWidgets('une matrice déclarée au clavier s’écrit à la main', (t) async {
    await monter(
      t,
      const EcritureManuscrite(
        latex: r'A=\begin{pmatrix}1&2\\3&4\end{pmatrix}',
        couleur: Colors.blue,
        repli: Text('repli'),
      ),
    );
    expect(find.text('repli'), findsNothing);
    expect(t.getSize(find.byType(EcritureManuscrite)).height, greaterThan(40));
  });

  testWidgets('une autre lecture, écrite à la main, se choisit', (t) async {
    var touche = 0;
    await monter(
      t,
      LectureManuscrite(
        latex: '2+3',
        couleur: Colors.blue,
        libelle: 'Choisir cette lecture : 2+3',
        surToucher: () => touche++,
      ),
    );
    expect(find.text('2+3'), findsNothing);
    expect(
      find.bySemanticsLabel('Choisir cette lecture : 2+3'),
      findsOneWidget,
    );
    expect(
      t.getSize(find.byType(LectureManuscrite)).height,
      greaterThanOrEqualTo(48),
    );
    await t.tap(find.byType(LectureManuscrite));
    expect(touche, 1);
  });
}
