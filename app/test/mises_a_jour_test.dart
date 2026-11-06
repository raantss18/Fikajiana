import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:fikajiana/mises_a_jour/mise_a_jour.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SimpleKeyPair cles;
  late String clePublique;

  setUp(() async {
    cles = await Ed25519().newKeyPair();
    final publique = await cles.extractPublicKey();
    clePublique = base64.encode(publique.bytes);
  });

  Future<(List<int>, String)> signer(Map<String, dynamic> json) async {
    final corps = utf8.encode(jsonEncode(json));
    final signature = await Ed25519().sign(corps, keyPair: cles);
    return (corps, base64.encode(signature.bytes));
  }

  final publication = {
    'format': 1,
    'latest': {
      'build': 2015,
      'version': '0.1.0',
      'notes': {'fr': 'Bonjour', 'en': 'Hello'},
      'apk': {'url': 'https://exemple/a.apk', 'sha256': 'ab', 'bytes': 12},
    },
  };

  test('un fichier bien signé est lu', () async {
    final (corps, signature) = await signer(publication);
    final v = await lireSigne(corps, signature, clePublique: clePublique);
    expect(v!.build, 2015);
    expect(v.notesPour('fr'), 'Bonjour');
    expect(v.notesPour('mg'), 'Hello');
  });

  test('un fichier modifié est refusé', () async {
    final (corps, signature) = await signer(publication);
    final modifie = [...corps]..[10] ^= 1;
    expect(
      await lireSigne(modifie, signature, clePublique: clePublique),
      isNull,
    );
  });

  test('une autre clé est refusée', () async {
    final (corps, signature) = await signer(publication);
    expect(await lireSigne(corps, signature), isNull);
  });

  test('un autre format est refusé', () async {
    final (corps, signature) = await signer({...publication, 'format': 2});
    expect(await lireSigne(corps, signature, clePublique: clePublique), isNull);
  });

  test('une signature illisible ne plante pas', () async {
    final (corps, _) = await signer(publication);
    expect(
      await lireSigne(corps, 'pas du base64!', clePublique: clePublique),
      isNull,
    );
  });

  test('la clé publique publiée fait 32 octets', () {
    expect(base64.decode(clePubliqueBase64), hasLength(32));
  });

  test('la publication vise bien ce dépôt', () {
    expect(urlPublication, contains('raantss18/Fikajiana'));
    expect(urlPublication, contains('latest'));
  });
}
