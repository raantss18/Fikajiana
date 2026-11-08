import 'package:fikajiana/comprendre/calcul_feuille.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/encre/vue_feuille.dart';
import 'package:fikajiana/l10n/gen/app_localizations.dart';
import 'package:fikajiana/moteur/giac.dart';
import 'package:fikajiana/moteur/moteur.dart';
import 'package:fikajiana/reconnaissance/lecteur.dart';
import 'package:fikajiana/reglages/reglages.dart';
import 'package:fikajiana/ui/calcul/carte_bloc.dart';
import 'package:fikajiana/ui/calcul/menu_actions.dart';
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
  testWidgets('x²−5x+6 : un seul bouton ouvre résoudre, dériver, tracer ; '
      'le choix pose la ligne', (t) async {
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
    var touches = 0;
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
                    surTouche: () => touches++,
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
    // Un seul petit bouton, et non une rangée de mots qui passait sur les
    // lignes voisines (téléphone d'Antsa, 2026-11-08).
    final bouton = find.byType(BoutonActions);
    expect(bouton, findsOneWidget);
    expect(
      find.bySemanticsLabel("Résoudre : écrire l'équation dessous"),
      findsNothing,
    );
    expect(
      find.bySemanticsLabel(RegExp('^Que faire de cette ligne : .*résoudre')),
      findsOneWidget,
    );
    // 48 dp, rangé avec 👍 et 👎, hors de l'encre.
    final zone = t.getRect(bouton);
    expect(zone.height, greaterThanOrEqualTo(48));
    expect(zone.width, greaterThanOrEqualTo(48));
    expect(zone.overlaps(bloc.cadre), isFalse);
    final pouce = t.getRect(find.byKey(ValueKey('faux-${bloc.cle}')));
    expect(zone.top, pouce.top);
    expect(zone.left, greaterThanOrEqualTo(pouce.right));

    // Le toucher ouvre le menu : chaque action, nommée pour TalkBack.
    await t.tap(bouton);
    await t.pumpAndSettle();
    // Le point laissé dans l'encre par ce toucher s'efface dès l'ouverture :
    // sinon il se lisait comme une ligne non comprise (Pad 7).
    expect(touches, 1);
    for (final nom in [
      "Résoudre : écrire l'équation dessous",
      'Dériver : écrire la dérivée dessous',
      'Tracer : écrire y = … dessous',
    ]) {
      expect(find.bySemanticsLabel(nom), findsOneWidget);
    }
    for (final e in t.widgetList(find.byType(PopupMenuItem<Proposition>))) {
      expect(t.getSize(find.byWidget(e)).height, greaterThanOrEqualTo(48));
    }
    await t.tap(find.bySemanticsLabel("Résoudre : écrire l'équation dessous"));
    await t.pumpAndSettle();
    expect(poses, [r'\text{résoudre}\left(x^{2}-5x+6=0\right)']);
    expect(find.byType(PopupMenuItem<Proposition>), findsNothing);

    // À confirmer : un pointillé que TalkBack nomme ; il part ensuite.
    expect(find.bySemanticsLabel('Lecture à confirmer'), findsNothing);
    bloc.aConfirmer = true;
    calcul.notifyListeners();
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Lecture à confirmer'), findsOneWidget);
  });

  testWidgets('une courbe écrite : le bouton se range avec 👍 et 👎, pas '
      'après « tracer » (téléphone, Pad 7)', (t) async {
    final encre = Encre();
    final calcul = CalculFeuille(
      encre: encre,
      lecteur: _Lecteur('f(x)=x^{2}'),
      moteur: _Moteur(),
      pause: Duration.zero,
    );
    addTearDown(calcul.dispose);
    await t.runAsync(() async {
      // Une ligne de la hauteur d'une écriture : 60 px.
      encre.commencer(const PointEncre(140, 100, 0.1));
      for (var i = 1; i < 6; i++) {
        encre.prolonger(PointEncre(140 + i * 4.0, 100 + i * 12.0, 0.1));
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
    expect(bloc.seTrace, isTrue);
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
                    surProposer: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final bouton = find.byType(BoutonActions);
    expect(bouton, findsOneWidget);
    final pouce = t.getRect(find.byKey(ValueKey('faux-${bloc.cle}')));
    expect(t.getRect(bouton).top, pouce.top);
    expect(t.getRect(bouton).overlaps(bloc.cadre), isFalse);
  });
}
