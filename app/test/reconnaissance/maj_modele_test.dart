import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' hide Hash;
import 'package:fikajiana/reconnaissance/modele.dart';
import 'package:flutter_test/flutter_test.dart';

const _noms = ['encoder_model.onnx', 'decoder_model.onnx', 'tokenizer.json'];

void main() {
  late Directory dossier;
  late HttpServer serveur;
  late SimpleKeyPair cle;
  late String clePublique;

  /// Ce que le serveur rend, par chemin.
  final pages = <String, List<int>>{};

  setUpAll(() async {
    // La liaison de test bloque le réseau ; ce serveur veut le vrai client.
    HttpOverrides.global = null;
    cle = await Ed25519().newKeyPair();
    clePublique = base64.encode((await cle.extractPublicKey()).bytes);
  });

  setUp(() async {
    dossier = Directory.systemTemp.createTempSync('fikajiana');
    pages.clear();
    serveur = await HttpServer.bind(InternetAddress.loopbackIPv4, 0)
      ..listen((requete) async {
        final page = pages[requete.uri.path];
        if (page == null) {
          requete.response.statusCode = HttpStatus.notFound;
        } else {
          requete.response.add(page);
        }
        await requete.response.close();
      });
  });

  tearDown(() async {
    await serveur.close(force: true);
    dossier.deleteSync(recursive: true);
  });

  String base() => 'http://127.0.0.1:${serveur.port}';

  /// Pose les trois fichiers d'une version sur le serveur et rend leur liste.
  List<FichierModele> poser(int version) => [
    for (final nom in _noms)
      () {
        final octets = utf8.encode('$nom, version $version');
        pages['/v$version/$nom'] = octets;
        return FichierModele(
          nom,
          octets.length,
          sha256.convert(octets).toString(),
        );
      }(),
  ];

  Future<void> publier(
    Map<String, dynamic> modele, {
    SimpleKeyPair? signePar,
  }) async {
    final corps = utf8.encode(jsonEncode({'format': 1, 'modele': modele}));
    final signature = await Ed25519().sign(corps, keyPair: signePar ?? cle);
    pages['/pub/modele.json'] = corps;
    pages['/pub/modele.json.sig'] = utf8.encode(base64.encode(signature.bytes));
  }

  Map<String, dynamic> fiche(int version, List<FichierModele> fichiers) =>
      ModelePublie(
        version: version,
        url: '${base()}/v$version',
        fichiers: fichiers,
      ).versJson();

  ModeleOcr modele() => ModeleOcr(
    dossier: '${dossier.path}/modele',
    url: '${base()}/v1',
    fichiers: poser(1),
    urlPublication: '${base()}/pub',
    clePublique: clePublique,
    httpsSeulement: false,
  );

  String lu(ModeleOcr m, String nom) =>
      File('${m.dossier}/$nom').readAsStringSync();

  test('un modèle plus récent, signé : proposé, installé, retrouvé', () async {
    final m = modele();
    await m.telecharger();
    expect(m.version, 1);
    await publier(fiche(2, poser(2)));
    await m.rechercherMiseAJour();
    expect(m.maj, EtatMajModele.disponible);
    expect(m.publie!.version, 2);
    await m.installerMiseAJour();
    expect(m.maj, EtatMajModele.installe);
    expect(m.etat, EtatModele.present);
    expect(m.version, 2);
    expect(lu(m, 'tokenizer.json'), 'tokenizer.json, version 2');
    // Au démarrage suivant : toujours présent, en version 2.
    final apres = modele();
    expect(apres.etat, EtatModele.present);
    expect(apres.version, 2);
    // Et plus rien à proposer.
    await apres.rechercherMiseAJour();
    expect(apres.maj, EtatMajModele.aJour);
  });

  test('même version : à jour, rien de téléchargé', () async {
    final m = modele();
    await m.telecharger();
    await publier(fiche(1, poser(1)));
    await m.rechercherMiseAJour();
    expect(m.maj, EtatMajModele.aJour);
    expect(m.publie, isNull);
  });

  test('signé par une autre clé : refusé', () async {
    final m = modele();
    await m.telecharger();
    await publier(fiche(2, poser(2)), signePar: await Ed25519().newKeyPair());
    await m.rechercherMiseAJour();
    expect(m.maj, EtatMajModele.echec);
    expect(m.publie, isNull);
  });

  test('un fichier au contenu changé : l’ancien modèle reste', () async {
    final m = modele();
    await m.telecharger();
    await publier(fiche(2, poser(2)));
    pages['/v2/decoder_model.onnx'] = utf8.encode('autre chose, même pas ça');
    await m.rechercherMiseAJour();
    await m.installerMiseAJour();
    expect(m.maj, EtatMajModele.echec);
    expect(m.etat, EtatModele.present);
    expect(m.version, 1);
    expect(lu(m, 'tokenizer.json'), 'tokenizer.json, version 1');
    expect(Directory('${m.dossier}.nouveau').existsSync(), isFalse);
    expect(modele().etat, EtatModele.present);
  });

  test('forme inattendue : noms de fichiers, chemin, http, empreinte', () {
    final bons = poser(2);
    Map<String, dynamic> premier(Map<String, dynamic> f) =>
        (f['fichiers'] as List).first as Map<String, dynamic>;
    Map<String, dynamic> avec(void Function(Map<String, dynamic>) change) {
      final f = jsonDecode(
        jsonEncode(
          ModelePublie(
            version: 2,
            url: 'https://exemple.org/v2',
            fichiers: bons,
          ).versJson(),
        ),
      ) as Map<String, dynamic>;
      change(f);
      return f;
    }

    expect(ModelePublie.depuisJson(avec((_) {})), isNotNull);
    expect(
      ModelePublie.depuisJson(avec((f) => f['url'] = 'http://exemple.org')),
      isNull,
    );
    expect(
      ModelePublie.depuisJson(avec((f) => premier(f)['nom'] = '../../evil')),
      isNull,
    );
    expect(
      ModelePublie.depuisJson(
        avec((f) => (f['fichiers'] as List).removeLast()),
      ),
      isNull,
    );
    expect(
      ModelePublie.depuisJson(avec((f) => premier(f)['sha256'] = 'abc')),
      isNull,
    );
    expect(
      ModelePublie.depuisJson(avec((f) => premier(f)['octets'] = 999999999999)),
      isNull,
    );
    expect(ModelePublie.depuisJson('pas une fiche'), isNull);
  });

  test('sans réseau : échec dit, rien de changé', () async {
    final m = modele();
    await m.telecharger();
    await m.rechercherMiseAJour(); // rien de publié : 404
    expect(m.maj, EtatMajModele.echec);
    expect(m.etat, EtatModele.present);
  });
}
