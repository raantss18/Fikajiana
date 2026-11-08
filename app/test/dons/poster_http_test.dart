import 'dart:convert';
import 'dart:io';

import 'package:fikajiana/dons/envoi_dons.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le POST réel annonce sa longueur et du JSON', () async {
    final serveur = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(serveur.close);
    final recu = <(int, String?, String)>[];
    serveur.listen((requete) async {
      final corps = await utf8.decodeStream(requete);
      recu.add((
        requete.contentLength,
        requete.headers.contentType?.mimeType,
        corps,
      ));
      requete.response.statusCode = 201;
      await requete.response.close();
    });
    // Un vrai client, même quand le binding des tests de widgets les
    // remplace (suite regroupée).
    final code = await HttpOverrides.runWithHttpOverrides(
      () => posterHttp(
        Uri.parse('http://127.0.0.1:${serveur.port}/v1/dons'),
        '{"é":1}',
      ),
      _ClientReel(),
    );
    expect(code, 201);
    final (longueur, type, corps) = recu.single;
    expect(longueur, utf8.encode('{"é":1}').length);
    expect(type, 'application/json');
    expect(corps, '{"é":1}');
  });
}

class _ClientReel extends HttpOverrides;
