import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fikajiana/reconnaissance/modele.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dossier;
  late HttpServer serveur;
  var contenu = <int>[];

  // La liaison de test bloque le réseau ; ce serveur local veut le vrai client.
  setUpAll(() => HttpOverrides.global = null);

  setUp(() async {
    dossier = Directory.systemTemp.createTempSync('fikajiana');
    contenu = 'poids du modèle'.codeUnits;
    serveur = await HttpServer.bind(InternetAddress.loopbackIPv4, 0)
      ..listen((requete) async {
        requete.response.add(contenu);
        await requete.response.close();
      });
  });

  tearDown(() async {
    await serveur.close(force: true);
    dossier.deleteSync(recursive: true);
  });

  ModeleOcr modele(List<int> attendu) => ModeleOcr(
    dossier: '${dossier.path}/modele',
    url: 'http://127.0.0.1:${serveur.port}',
    fichiers: [
      FichierModele(
        'a.onnx',
        attendu.length,
        sha256.convert(attendu).toString(),
      ),
    ],
  );

  test('absent au départ', () {
    expect(modele(contenu).etat, EtatModele.absent);
  });

  test('téléchargé si l’empreinte est juste, et retrouvé ensuite', () async {
    final m = modele(contenu);
    await m.telecharger();
    expect(m.etat, EtatModele.present);
    expect(m.progression, 1);
    expect(modele(contenu).etat, EtatModele.present);
  });

  test('une empreinte fausse n’installe rien', () async {
    final m = modele('autre chose de même...'.codeUnits);
    await m.telecharger();
    expect(m.etat, EtatModele.echec);
    expect(File('${m.dossier}/a.onnx').existsSync(), isFalse);
    expect(File('${m.dossier}/a.onnx.partiel').existsSync(), isFalse);
  });

  test('supprimer revient à l’état absent', () async {
    final m = modele(contenu);
    await m.telecharger();
    await m.supprimer();
    expect(m.etat, EtatModele.absent);
    expect(Directory(m.dossier!).existsSync(), isFalse);
  });

  test('sans dossier, ne fait rien', () async {
    final m = ModeleOcr(dossier: null);
    await m.telecharger();
    expect(m.etat, EtatModele.absent);
  });

  test('les fichiers publiés sont bien épinglés', () {
    expect(urlModele, contains(revisionModele));
    expect(fichiersModele, hasLength(3));
    for (final f in fichiersModele) {
      expect(f.sha256, hasLength(64));
    }
  });
}
