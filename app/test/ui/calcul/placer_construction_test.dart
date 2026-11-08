import 'package:fikajiana/comprendre/calcul_feuille.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/geometrie/atelier.dart';
import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/moteur/giac.dart';
import 'package:fikajiana/moteur/moteur.dart';
import 'package:fikajiana/reconnaissance/lecteur.dart';
import 'package:fikajiana/ui/calcul/placer_construction.dart';
import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Lecteur extends Lecteur {
  @override
  Future<String> lire(List<Trait> traits) async => '';
}

/// Note ce qu'on demande à Giac, et dans quelle unité d'angle.
class _Moteur implements Moteur {
  final entrees = <(String, bool)>[];

  @override
  Future<ReponseGiac> calculer(String entree, {bool degres = false}) async {
    entrees.add((entree, degres));
    return const ReponseGiac(exact: '1', latex: '1', approche: '1.0');
  }

  @override
  void interrompre() {}
}

void main() {
  group('la Feuille comprend les constructions et les mesures', () {
    Future<(CalculFeuille, _Moteur)> feuille(List<String> lignes) async {
      final moteur = _Moteur();
      final calcul = CalculFeuille(
        encre: Encre(),
        lecteur: _Lecteur(),
        moteur: moteur,
        pause: Duration.zero,
      );
      addTearDown(calcul.dispose);
      var y = 0.0;
      for (final l in ['A(0;0)', 'B(4;0)', 'C(1;3)', ...lignes]) {
        await calcul.saisir(l, Offset(0, y += 100));
      }
      return (calcul, moteur);
    }

    test('parallèle((AB);C) : une construction à placer, sans Giac', () async {
      final (calcul, moteur) = await feuille(['parallèle((AB);C)']);
      final b = calcul.blocs.last;
      expect(b.etat, EtatBloc.fait);
      expect(b.commande?.genre, GenreCommande.parallele);
      expect(b.aPlacer.map((o) => o.nom), ['A', 'B', 'C']);
      expect(moteur.entrees, isEmpty);
      // Ce que fait « Placer » : les points, puis la construction.
      final atelier = Atelier();
      b.aPlacer.forEach(atelier.placerObjet);
      expect(atelier.construire(b.commande!), isTrue);
      expect(atelier.formes.values.whereType<DroiteGeo>(), hasLength(2));
    });

    test('angle, aire, périmètre partent à Giac', () async {
      final (_, moteur) = await feuille([
        'angle(A;B;C)=',
        'aire(ABC)=',
        'périmètre(ABC)=',
      ]);
      final envoyes = moteur.entrees.map((e) => e.$1).join('\n');
      expect(envoyes, contains('acos('));
      expect(envoyes, contains('abs('));
      expect(envoyes, contains('sqrt('));
    });
  });

  group('Placer dit ce qui manque', () {
    Future<bool?> placer(WidgetTester t, Atelier a, String ecrit) async {
      bool? fait;
      await t.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    fait = placerConstruction(context, a, lireCommande(ecrit)!),
                child: const Text('Placer'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Placer'));
      await t.pump();
      return fait;
    }

    Atelier triangle() => Atelier()
      ..placerObjet(const PointLu('A', 0, 0))
      ..placerObjet(const PointLu('B', 4, 0))
      ..placerObjet(const PointLu('C', 1, 3));

    testWidgets('une droite nommée absente', (t) async {
      expect(await placer(t, triangle(), 'parallèle(d;C)'), isFalse);
      expect(
        find.text("« d » n'est pas dans la Figure : placez-le d'abord."),
        findsOneWidget,
      );
    });

    testWidgets('un cercle là où il faut une droite', (t) async {
      final a = triangle()..construire(lireCommande('k=cercle(A;2)')!);
      expect(await placer(t, a, 'parallèle(k;C)'), isFalse);
      expect(
        find.text('Cette construction ne se fait pas avec ces objets.'),
        findsOneWidget,
      );
    });

    testWidgets('tout est là : rien à dire', (t) async {
      expect(await placer(t, triangle(), 'parallèle((AB);C)'), isTrue);
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
