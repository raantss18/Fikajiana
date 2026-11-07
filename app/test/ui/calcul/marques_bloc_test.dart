import 'package:fikajiana/l10n/gen/app_localizations.dart';
import 'package:fikajiana/ui/calcul/marques_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _dans(Widget enfant, {bool sansAnimation = false}) => MaterialApp(
  locale: const Locale('fr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(400, 800),
      disableAnimations: sansAnimation,
    ),
    child: Scaffold(body: enfant),
  ),
);

void main() {
  group('la lueur de lecture', () {
    testWidgets('bouge, sans prendre le stylet', (t) async {
      await t.pumpWidget(
        _dans(
          const SizedBox(
            width: 100,
            height: 40,
            child: LueurLecture(couleur: Colors.brown),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 300));
      expect(t.binding.hasScheduledFrame, isTrue);
      expect(find.byType(LueurLecture), findsOneWidget);
    });

    testWidgets("reste posée si l'appareil coupe les animations", (t) async {
      await t.pumpWidget(
        _dans(
          const SizedBox(
            width: 100,
            height: 40,
            child: LueurLecture(couleur: Colors.brown),
          ),
          sansAnimation: true,
        ),
      );
      await t.pump();
      expect(t.binding.hasScheduledFrame, isFalse);
    });
  });

  group('le trait ondulé', () {
    testWidgets("s'écrit puis s'arrête", (t) async {
      await t.pumpWidget(
        _dans(
          const SizedBox(
            width: 100,
            height: 48,
            child: VagueAVerifier(couleur: Colors.brown),
          ),
        ),
      );
      expect(t.binding.hasScheduledFrame, isTrue);
      await t.pumpAndSettle();
      expect(t.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('laisse passer le stylet à la feuille', (t) async {
      var feuille = 0;
      await t.pumpWidget(
        _dans(
          Stack(
            fit: StackFit.expand,
            children: [
              Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => feuille++,
              ),
              const Positioned(
                left: 10,
                top: 10,
                width: 100,
                height: 48,
                child: VagueAVerifier(couleur: Colors.brown),
              ),
            ],
          ),
        ),
      );
      await t.tapAt(t.getCenter(find.byType(VagueAVerifier)));
      expect(feuille, 1);
    });
  });

  group('le panneau', () {
    Future<void> ouvrir(
      WidgetTester t,
      void Function(ChoixBloc?) surChoix, {
      Offset ancre = const Offset(20, 100),
    }) async {
      await t.pumpWidget(
        _dans(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                surChoix(
                  await ouvrirPanneauBloc(
                    context,
                    ancre: ancre,
                    message: 'Lu ainsi',
                    lecture: const Text('x+'),
                    effacer: 'Effacer',
                  ),
                );
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
      );
      await t.tap(find.text('ouvrir'));
      await t.pumpAndSettle();
    }

    testWidgets('montre ce qui a été lu et ses deux choix', (t) async {
      ChoixBloc? choix;
      await ouvrir(t, (c) => choix = c);
      expect(find.text('Lu ainsi'), findsOneWidget);
      expect(find.text('x+'), findsOneWidget);
      expect(
        t.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(40),
      );
      await t.tap(find.text('Corriger'));
      await t.pumpAndSettle();
      expect(choix, ChoixBloc.corriger);
    });

    testWidgets('efface sur demande', (t) async {
      ChoixBloc? choix;
      await ouvrir(t, (c) => choix = c);
      await t.tap(find.text('Effacer'));
      await t.pumpAndSettle();
      expect(choix, ChoixBloc.effacer);
    });

    testWidgets('se ferme en touchant à côté', (t) async {
      ChoixBloc? choix = ChoixBloc.effacer;
      await ouvrir(t, (c) => choix = c);
      await t.tapAt(const Offset(390, 590));
      await t.pumpAndSettle();
      expect(choix, isNull);
      expect(find.text('Lu ainsi'), findsNothing);
    });

    testWidgets("s'ouvre au-dessus en bas de l'écran", (t) async {
      await ouvrir(t, (_) {}, ancre: const Offset(20, 790));
      expect(t.getBottomLeft(find.byType(FilledButton)).dy, lessThan(780));
    });
  });
}
