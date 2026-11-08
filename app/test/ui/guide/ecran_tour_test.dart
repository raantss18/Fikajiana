import 'package:fikajiana/comprendre/carnet.dart';
import 'package:fikajiana/comprendre/classeur.dart';
import 'package:fikajiana/geometrie/atelier.dart';
import 'package:fikajiana/graphe/courbes.dart';
import 'package:fikajiana/moteur/giac.dart';
import 'package:fikajiana/moteur/moteur.dart';
import 'package:fikajiana/reconnaissance/lecteur.dart';
import 'package:fikajiana/reconnaissance/modele.dart';
import 'package:fikajiana/reglages/reglages.dart';
import 'package:fikajiana/ui/app.dart';
import 'package:fikajiana/ui/calcul/ecran_feuille.dart';
import 'package:fikajiana/ui/ecriture_animee.dart';
import 'package:fikajiana/ui/guide/ecran_tour.dart';
import 'package:fikajiana/ui/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Moteur implements Moteur {
  @override
  Future<ReponseGiac> calculer(String entree, {bool degres = false}) async =>
      const ReponseGiac(exact: '6', latex: '6', approche: '6.0');

  @override
  void interrompre() {}
}

/// Un modèle qu'on fait arriver quand on veut, sans fichier.
class _Modele extends ModeleOcr {
  new(this._etatFaux) : super(dossier: null);

  EtatModele _etatFaux;

  @override
  EtatModele get etat => _etatFaux;

  void arriver() {
    _etatFaux = EtatModele.present;
    notifyListeners();
  }
}

Services _services(ModeleOcr modele, {String? version = '1.0.6'}) => Services(
  modele: modele,
  lecteur: LecteurPix2Text(modele),
  moteur: _Moteur(),
  courbes: Courbes(),
  atelier: Atelier(),
  carnet: Carnet(),
  graphes: Classeur(),
  figures: Classeur(),
  lireVersion: () async => version,
);

Future<void> _lancer(
  WidgetTester t, {
  required Services services,
  Reglages? reglages,
  Size taille = const Size(400, 800),
  Locale langue = const Locale('fr'),
}) async {
  t.view.physicalSize = taille;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.localesTestValue = [langue];
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearAllTestValues);
  await t.pumpWidget(App(services: services, reglages: reglages));
  await t.pumpAndSettle();
}

final Finder _proposition = find.text('Un petit tour ?');

void main() {
  group('la proposition du tour', () {
    testWidgets('après une mise à jour, modèle là : proposé une fois', (
      t,
    ) async {
      SharedPreferences.setMockInitialValues({'tour_propose': '1.0.5'});
      final stockage = await SharedPreferences.getInstance();
      final reglages = Reglages(stockage: stockage);
      final services = _services(_Modele(EtatModele.present));
      await _lancer(t, services: services, reglages: reglages);

      expect(_proposition, findsOneWidget);
      expect(find.textContaining('1.0.6'), findsOneWidget);
      await t.tap(find.text('Plus tard'));
      await t.pumpAndSettle();
      expect(_proposition, findsNothing);
      expect(reglages.tourPropose, '1.0.6');
      expect(
        (await SharedPreferences.getInstance()).getString('tour_propose'),
        '1.0.6',
      );

      // Relancée, la même version ne repose pas la question.
      await t.pumpWidget(const SizedBox());
      await _lancer(t, services: services, reglages: reglages);
      expect(_proposition, findsNothing);
    });

    testWidgets('sans modèle, rien ; le modèle arrivé, le tour se propose', (
      t,
    ) async {
      final modele = _Modele(EtatModele.absent);
      await _lancer(t, services: _services(modele), reglages: Reglages());
      expect(_proposition, findsNothing);

      modele.arriver();
      await t.pumpAndSettle();
      expect(_proposition, findsOneWidget);
    });

    testWidgets('version inconnue (hors Android) : rien', (t) async {
      await _lancer(
        t,
        services: _services(_Modele(EtatModele.present), version: null),
        reglages: Reglages(),
      );
      expect(_proposition, findsNothing);
    });

    testWidgets('« Faire le tour » le parcourt, puis revient à la Feuille', (
      t,
    ) async {
      await _lancer(
        t,
        services: _services(_Modele(EtatModele.present)),
        reglages: Reglages(),
      );
      await t.tap(find.text('Faire le tour'));
      await t.pumpAndSettle();
      expect(find.byType(EcranTour), findsOneWidget);
      expect(find.text('Étape 1 sur 6'), findsOneWidget);

      for (var i = 2; i <= 6; i++) {
        await t.tap(find.text('Suivant'));
        await t.pumpAndSettle();
        expect(find.text('Étape $i sur 6'), findsOneWidget);
      }
      expect(find.text('Suivant'), findsNothing);
      await t.tap(find.text('Précédent'));
      await t.pumpAndSettle();
      expect(find.text('Étape 5 sur 6'), findsOneWidget);
      await t.tap(find.text('Suivant'));
      await t.pumpAndSettle();

      await t.tap(find.text('Écrire sur la feuille'));
      await t.pumpAndSettle();
      expect(find.byType(EcranTour), findsNothing);
      expect(find.byType(EcranFeuille), findsOneWidget);
    });
  });

  testWidgets('le Guide ouvre le tour, et le tour rouvre le Guide', (t) async {
    await _lancer(
      t,
      services: _services(_Modele(EtatModele.absent)),
      reglages: Reglages(),
    );
    await t.tap(find.byTooltip('Menu'));
    await t.pumpAndSettle();
    await t.tap(find.text('Guide').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Faire le tour'));
    await t.pumpAndSettle();
    expect(find.byType(EcranTour), findsOneWidget);

    await t.tap(find.text('Passer le tour'));
    await t.pumpAndSettle();
    expect(find.byType(EcranFeuille), findsOneWidget);
  });

  testWidgets('l’exemple s’écrit trait par trait, et un toucher le réécrit', (
    t,
  ) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EcritureAnimee(
            lignes: [LigneEcrite('2+3=', '5')],
            indiceRejouer: 'réécrire',
          ),
        ),
      ),
    );
    final peintre = find.descendant(
      of: find.byType(EcritureAnimee),
      matching: find.byType(CustomPaint),
    );
    double avancee() =>
        (t.widget<CustomPaint>(peintre).painter! as PeintreEcriture).avancee;
    expect(avancee(), 0);
    await t.pump(const Duration(milliseconds: 300));
    expect(avancee(), inExclusiveRange(0, 1));
    await t.pumpAndSettle();
    expect(avancee(), 1);

    await t.tap(find.byType(EcritureAnimee));
    await t.pump();
    expect(avancee(), lessThan(0.2));
    await t.pumpAndSettle();
    expect(find.bySemanticsLabel('2+3= 5'), findsOneWidget);
  });

  testWidgets('animations coupées : tout est écrit d’emblée', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: EcritureAnimee(lignes: [LigneEcrite('2+3=', '5')]),
          ),
        ),
      ),
    );
    final peintre = t.widget<CustomPaint>(
      find.descendant(
        of: find.byType(EcritureAnimee),
        matching: find.byType(CustomPaint),
      ),
    );
    expect((peintre.painter! as PeintreEcriture).avancee, 1);
  });

  for (final (nom, taille) in [
    ('téléphone', const Size(360, 740)),
    ('tablette', const Size(800, 1280)),
    ('paysage', const Size(800, 360)),
  ]) {
    for (final langue in const [Locale('fr'), Locale('en')]) {
      testWidgets('tour, $nom (${langue.languageCode}) : rien ne déborde', (
        t,
      ) async {
        await _lancer(
          t,
          services: _services(_Modele(EtatModele.absent)),
          reglages: Reglages(),
          taille: taille,
          langue: langue,
        );
        // La route ne se termine qu'au retour : on ne l'attend pas.
        t
            .state<NavigatorState>(find.byType(Navigator))
            .push(MaterialPageRoute<void>(builder: (_) => const EcranTour()));
        await t.pumpAndSettle();
        final suivant = langue.languageCode == 'fr' ? 'Suivant' : 'Next';
        for (var i = 0; i < 6; i++) {
          expect(t.takeException(), isNull);
          await expectLater(t, meetsGuideline(androidTapTargetGuideline));
          await expectLater(t, meetsGuideline(textContrastGuideline));
          if (i < 5) {
            await t.tap(find.text(suivant));
            await t.pumpAndSettle();
          }
        }
        expect(find.text(suivant), findsNothing);
      });
    }
  }
}
