import 'package:fikajiana/comprendre/calcul_feuille.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/encre/vue_feuille.dart';
import 'package:fikajiana/l10n/gen/app_localizations.dart';
import 'package:fikajiana/moteur/giac.dart';
import 'package:fikajiana/moteur/moteur.dart';
import 'package:fikajiana/reconnaissance/lecteur.dart';
import 'package:fikajiana/reglages/reglages.dart';
import 'package:fikajiana/ui/calcul/action_manuscrite.dart';
import 'package:fikajiana/ui/calcul/carte_bloc.dart';
import 'package:fikajiana/ui/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Lecteur extends Lecteur {
  new(this.reponse);
  final String reponse;

  @override
  Future<String> lire(List<Trait> traits) async => reponse;

  @override
  Future<List<String>> lirePlusieurs(List<Trait> traits) async => [reponse];
}

class _Moteur implements Moteur {
  @override
  Future<ReponseGiac> calculer(String entree, {bool degres = false}) async =>
      ReponseGiac(exact: entree, latex: entree, approche: entree);

  @override
  void interrompre() {}
}

void main() {
  testWidgets('x²−5x+6 propose résoudre, dériver, tracer ; un toucher pose '
      'la ligne', (t) async {
    final encre = Encre();
    final calcul = CalculFeuille(
      encre: encre,
      lecteur: _Lecteur('x^{2}-5x+6'),
      moteur: _Moteur(),
      pause: Duration.zero,
    );
    addTearDown(calcul.dispose);
    await t.runAsync(() async {
      encre.commencer(const PointEncre(40, 100, 0.1));
      for (var i = 1; i < 6; i++) {
        encre.prolonger(PointEncre(40 + i * 4.0, 100, 0.1));
      }
      encre.terminer();
      calcul.encreChangee();
      for (var i = 0; i < 100; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        if (calcul.blocs.isNotEmpty &&
            calcul.blocs.single.etat == EtatBloc.fait) {
          break;
        }
      }
    });
    final bloc = calcul.blocs.single;
    final poses = <String>[];
    final vue = VueFeuille();
    addTearDown(vue.dispose);
    await t.pumpWidget(
      PorteeServices(
        services: Services.enMemoire(),
        child: PorteeReglages(
          reglages: Reglages(),
          child: MaterialApp(
            locale: const Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Stack(
                children: [
                  RepereBloc(
                    bloc: bloc,
                    calcul: calcul,
                    vue: vue,
                    surTouche: () {},
                    surEffacer: () {},
                    surProposer: poses.add,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    for (final nom in [
      "Résoudre : écrire l'équation dessous",
      'Dériver : écrire la dérivée dessous',
      'Tracer : écrire y = … dessous',
    ]) {
      expect(find.bySemanticsLabel(nom), findsOneWidget);
    }
    // Écrits à la main, de 48 dp au moins.
    for (final a in t.widgetList(find.byType(ActionManuscrite))) {
      expect(t.getSize(find.byWidget(a)).height, greaterThanOrEqualTo(48));
    }
    await t.tap(find.byTooltip("Résoudre : écrire l'équation dessous"));
    expect(poses, [r'\text{résoudre}\left(x^{2}-5x+6=0\right)']);
  });
}
