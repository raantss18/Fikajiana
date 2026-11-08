import 'dart:convert';
import 'dart:io';

import 'package:fikajiana/dons/envoi_dons.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/l10n/gen/app_localizations.dart';
import 'package:fikajiana/reconnaissance/ecritures.dart';
import 'package:fikajiana/reglages/reglages.dart';
import 'package:fikajiana/ui/reglages/ecran_reglages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<Trait> _traits(String nom) =>
    (Encre()..chargerDocument(
          jsonDecode(File('test/fixtures/pad7/$nom.json').readAsStringSync())
              as List<dynamic>,
        ))
        .traits
        .toList();

const _case = Rect.fromLTWH(10, 20, 300, 40);

Future<InfosAppareil> _infos() async => (
  modele: '2410CRP4CG',
  ecranDp: const Size(1164, 777),
  densite: 2.75,
  versionApp: '1.0.5+15',
);

void main() {
  late Ecritures ecritures;
  late Reglages reglages;
  late List<(Uri, String)> envois;
  late int reponse;
  late EtatReseau etat;

  EnvoiDons envoi() => EnvoiDons(
    ecritures: ecritures,
    reglages: reglages,
    infos: _infos,
    reseau: () async => etat,
    poster: (adresse, corps) async {
      envois.add((adresse, corps));
      return reponse;
    },
  );

  setUp(() async {
    ecritures = Ecritures();
    reglages = Reglages();
    envois = [];
    reponse = 201;
    etat = (connecte: true, nonFacture: true);
    final traits = _traits('trente_fois_8');
    await ecritures.jugerJuste(traits, r'30\times8', _case, [
      (traits.take(1).toList(), '3', _case),
    ]);
  });

  group('consentement (ADR 0042)', () {
    test('par défaut : non, Wi-Fi seulement, la plateforme d’Antsa', () {
      expect(reglages.donner, isFalse);
      expect(reglages.consentementDemande, isFalse);
      expect(reglages.wifiSeulement, isTrue);
      expect(reglages.adressePlateforme, adresseDonsParDefaut);
    });

    testWidgets('la question, case non cochée ; Continuer sans cocher : non', (
      tester,
    ) async {
      await tester.pumpWidget(_App(reglages));
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
      final caseACocher = tester.widget<CheckboxListTile>(
        find.byKey(const ValueKey('consentement-case')),
      );
      expect(caseACocher.value, isFalse);
      // Ni le fond ni un glissement ne la ferment : il faut répondre.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Continuer'), findsOneWidget);
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(reglages.consentementDemande, isTrue);
      expect(reglages.donner, isFalse);
    });

    testWidgets('cocher puis Continuer : oui ; la question ne revient pas', (
      tester,
    ) async {
      await tester.pumpWidget(_App(reglages));
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('consentement-case')));
      await tester.pump();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(reglages.donner, isTrue);
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
      expect(find.text('Continuer'), findsNothing);
    });
  });

  group('envoi (ADR 0042)', () {
    test('sans oui, rien ne part', () async {
      reglages.adressePlateforme = 'https://dons.exemple.org';
      expect(await envoi().envoyer(), BilanEnvoi.rien);
      expect(envois, isEmpty);
    });

    test('sans adresse, rien ne part', () async {
      reglages
        ..donner = true
        ..adressePlateforme = '';
      expect(await envoi().envoyer(), BilanEnvoi.rien);
      expect(envois, isEmpty);
    });

    test('une adresse sans HTTPS n’est pas prise, sauf vers l’appareil', () {
      expect(EnvoiDons.adresseSure('http://dons.exemple.org'), isNull);
      expect(EnvoiDons.adresseSure('ftp://x'), isNull);
      expect(EnvoiDons.adresseSure('pas une adresse'), isNull);
      expect(
        EnvoiDons.adresseSure('https://dons.exemple.org/api').toString(),
        'https://dons.exemple.org/api/',
      );
      expect(EnvoiDons.adresseSure('http://localhost:8765'), isNotNull);
      expect(EnvoiDons.adresseSure('http://127.0.0.1:8765'), isNotNull);
    });

    test('Wi-Fi seulement : rien sur un réseau facturé', () async {
      reglages
        ..donner = true
        ..adressePlateforme = 'https://dons.exemple.org';
      etat = (connecte: true, nonFacture: false);
      expect(await envoi().envoyer(), BilanEnvoi.horsReseau);
      etat = (connecte: false, nonFacture: false);
      expect(await envoi().envoyer(), BilanEnvoi.horsReseau);
      expect(envois, isEmpty);
      reglages.wifiSeulement = false;
      etat = (connecte: true, nonFacture: false);
      expect(await envoi().envoyer(), BilanEnvoi.envoye);
      expect(envois, hasLength(1));
    });

    test(
      'avec oui et adresse : le format de la plateforme, sans nom',
      () async {
        reglages
          ..donner = true
          ..adressePlateforme = 'https://dons.exemple.org/';
        expect(ecritures.lignesEnAttente, 1);
        expect(await envoi().envoyer(), BilanEnvoi.envoye);
        final (adresse, corps) = envois.single;
        expect(adresse.toString(), 'https://dons.exemple.org/v1/dons');
        final json = jsonDecode(corps) as Map<String, dynamic>;
        expect(json.keys.toSet(), {
          'format',
          'licence',
          'contributeur',
          'version_app',
          'appareil',
          'outil',
          'debut',
          'echantillons',
        });
        expect(json['licence'], 'CC0-1.0');
        expect(json['contributeur'], reglages.contributeur);
        expect(
          json['contributeur'],
          matches(RegExp(r'^[A-Za-z0-9_-]{16,64}$')),
        );
        expect(json['version_app'], '1.0.5+15');
        expect(json.containsKey('auteur'), isFalse);
        final ech = (json['echantillons'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        expect([for (final e in ech) e['type']], ['expression', 'signe']);
        // Parti : la file est vide, rien ne repart.
        expect(ecritures.lignesEnAttente, 0);
        expect(await envoi().envoyer(), BilanEnvoi.rien);
        expect(envois, hasLength(1));
      },
    );

    test('plateforme absente : on garde et on réessaiera', () async {
      reglages
        ..donner = true
        ..adressePlateforme = 'https://dons.exemple.org';
      reponse = 503;
      expect(await envoi().envoyer(), BilanEnvoi.aReessayer);
      expect(ecritures.lignesEnAttente, 1);
      final hors = EnvoiDons(
        ecritures: ecritures,
        reglages: reglages,
        infos: _infos,
        reseau: () async => etat,
        poster: (_, _) async => throw const SocketException('hors ligne'),
      );
      expect(await hors.envoyer(), BilanEnvoi.aReessayer);
      expect(ecritures.lignesEnAttente, 1);
    });

    test('par paquets', () {
      final traits = _traits('e_x_egal_7');
      return () async {
        await ecritures.jugerJuste(traits, 'e^{x}=7', _case, const []);
        final dons = ecritures.dons(
          contributeur: reglages.contributeur,
          modele: 'Pad 7',
          ecranDp: const Size(1164, 777),
          densite: 2.75,
          echantillonsMax: 1,
        );
        expect(dons, hasLength(3));
        expect(dons.every((d) => d.ids.length == 1), isTrue);
      }();
    });

    test('identifiant retiré (410) : un nouveau', () async {
      reglages
        ..donner = true
        ..adressePlateforme = 'https://dons.exemple.org';
      final avant = reglages.contributeur;
      reponse = 410;
      expect(await envoi().envoyer(), BilanEnvoi.aReessayer);
      expect(reglages.contributeur, isNot(avant));
      expect(ecritures.lignesEnAttente, 1);
    });

    test('demander le retrait : l’identifiant, puis un nouveau', () async {
      reglages.adressePlateforme = 'https://dons.exemple.org';
      final avant = reglages.contributeur;
      reponse = 202;
      expect(await envoi().demanderRetrait(), isTrue);
      final (adresse, corps) = envois.single;
      expect(adresse.toString(), 'https://dons.exemple.org/v1/retrait');
      expect(jsonDecode(corps), {'contributeur': avant});
      expect(reglages.contributeur, isNot(avant));
      reponse = 500;
      expect(await envoi().demanderRetrait(), isFalse);
      reglages.adressePlateforme = '';
      expect(await envoi().demanderRetrait(), isFalse);
    });
  });
}

class _App extends StatelessWidget {
  const new(this.reglages);
  final Reglages reglages;

  @override
  Widget build(BuildContext context) => PorteeReglages(
    reglages: reglages,
    child: MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => demanderConsentement(context),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    ),
  );
}
