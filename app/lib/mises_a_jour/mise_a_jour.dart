/// Mise à jour faite par l'app, à la demande (ADR 0015), comme COMIMa et
/// zanakiantsa :
///   1. `release.json` est signé (Ed25519) : la clé publique est dans l'app ;
///   2. l'APK téléchargé doit avoir l'empreinte SHA-256 de ce fichier signé ;
///   3. l'installateur Android exige la même clé de signature que l'app.
///
/// Le format ne change jamais : toute version doit savoir lire la dernière.
/// `{"format":1,"latest":{"build","version","notes":{"fr","en"},
/// "apk":{"url","sha256","bytes"}}}`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:fikajiana/reconnaissance/modele.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Remplaçable pour les essais.
const String urlPublication = String.fromEnvironment(
  'UPDATE_URL',
  defaultValue:
      'https://github.com/raantss18/Fikajiana/releases/latest/download',
);

/// Clé publique Ed25519. La clé privée est dans `release-keys/`, hors de Git.
const String clePubliqueBase64 = 'x0K7GNrUrRDDYSy/P7+mMtVLczvkVtRJM3vEIlpJQHg=';

/// Taille maximale de `release.json` et de sa signature.
const int _descriptionMax = 64 * 1024;

class VersionPubliee {
  new(Map<String, dynamic> json)
    : build = json['build'] as int,
      version = json['version'] as String,
      notes = Map<String, String>.from(json['notes'] as Map),
      url = (json['apk'] as Map)['url'] as String,
      sha256 = (json['apk'] as Map)['sha256'] as String,
      octets = (json['apk'] as Map)['bytes'] as int;

  final int build;
  final int octets;
  final String version;
  final String url;
  final String sha256;
  final Map<String, String> notes;

  String notesPour(String langue) => notes[langue] ?? notes['en'] ?? '';
}

/// La version annoncée, ou `null` si la signature ou le contenu est faux.
Future<VersionPubliee?> lireSigne(
  List<int> corps,
  String signatureBase64, {
  String clePublique = clePubliqueBase64,
}) async {
  try {
    final valide = await Ed25519().verify(
      corps,
      signature: Signature(
        base64.decode(signatureBase64.trim()),
        publicKey: SimplePublicKey(
          base64.decode(clePublique),
          type: KeyPairType.ed25519,
        ),
      ),
    );
    if (!valide) return null;
    final json = jsonDecode(utf8.decode(corps)) as Map<String, dynamic>;
    if (json['format'] != 1) return null;
    return VersionPubliee(Map<String, dynamic>.from(json['latest'] as Map));
  } on Object {
    return null;
  }
}

enum EtatMiseAJour {
  repos,
  recherche,
  aJour,
  disponible,
  telechargement,
  installation,
  echec,
}

class MiseAJour extends ChangeNotifier {
  new({this.url = urlPublication});

  static const _canal = MethodChannel('fikajiana/systeme');

  final String url;
  EtatMiseAJour etat = EtatMiseAJour.repos;
  VersionPubliee? publiee;
  double progression = 0;
  String? versionInstallee;

  Future<void> lireVersion() async {
    try {
      versionInstallee = await _canal.invokeMethod<String>('version');
      notifyListeners();
    } on Object {
      // Pas de canal hors d'Android : rien à afficher.
    }
  }

  void _etat(EtatMiseAJour nouveau) {
    etat = nouveau;
    notifyListeners();
  }

  /// Seul moment où l'app interroge le réseau pour une version : sur demande.
  Future<void> rechercher() async {
    _etat(EtatMiseAJour.recherche);
    final client = HttpClient();
    try {
      final corps = await _lire(client, '$url/release.json');
      final signature = await _lire(client, '$url/release.json.sig');
      final version = await lireSigne(corps, utf8.decode(signature));
      final build = await _canal.invokeMethod<int>('build') ?? 0;
      if (version == null) {
        _etat(EtatMiseAJour.echec);
      } else if (version.build <= build) {
        _etat(EtatMiseAJour.aJour);
      } else {
        publiee = version;
        _etat(EtatMiseAJour.disponible);
      }
    } on Object {
      _etat(EtatMiseAJour.echec);
    } finally {
      client.close(force: true);
    }
  }

  Future<List<int>> _lire(HttpClient client, String adresse) async {
    final requete = await client.getUrl(Uri.parse(adresse));
    final reponse = await requete.close().timeout(const Duration(seconds: 20));
    if (reponse.statusCode != HttpStatus.ok) {
      throw HttpException('statut ${reponse.statusCode}');
    }
    // Bornés en taille et en temps : release.json fait moins d'un kilo-octet.
    final octets = <int>[];
    await for (final morceau in reponse.timeout(const Duration(seconds: 20))) {
      octets.addAll(morceau);
      if (octets.length > _descriptionMax) {
        throw const FormatException('description trop grande');
      }
    }
    return octets;
  }

  /// Télécharge, vérifie l'empreinte, puis ouvre l'installateur d'Android.
  Future<void> installer(String dossierCache) async {
    final version = publiee;
    if (version == null) return;
    _etat(EtatMiseAJour.telechargement);
    final client = HttpClient();
    try {
      final dossier = Directory('$dossierCache/updates');
      // Les téléchargements d'avant ne restent pas dans le cache.
      if (dossier.existsSync()) dossier.deleteSync(recursive: true);
      dossier.createSync(recursive: true);
      final fichier = File('${dossier.path}/fikajiana-${version.build}.apk');
      final requete = await client.getUrl(Uri.parse(version.url));
      final reponse = await requete.close().timeout(
        const Duration(seconds: 20),
      );
      if (reponse.statusCode != HttpStatus.ok) {
        throw HttpException('statut ${reponse.statusCode}');
      }
      final sortie = fichier.openWrite();
      final condense = AccumulatorSink<crypto.Digest>();
      final empreinte = crypto.sha256.startChunkedConversion(condense);
      var recus = 0;
      // Un flux muet une minute, ou plus long qu'annoncé, est abandonné.
      await for (final morceau in reponse.timeout(
        const Duration(seconds: 60),
      )) {
        recus += morceau.length;
        if (version.octets > 0 && recus > version.octets) {
          await sortie.close();
          await fichier.delete();
          throw const FormatException('fichier plus grand qu’annoncé');
        }
        sortie.add(morceau);
        empreinte.add(morceau);
        progression = version.octets > 0 ? recus / version.octets : 0;
        notifyListeners();
      }
      await sortie.close();
      empreinte.close();
      if (condense.events.single.toString() != version.sha256.toLowerCase()) {
        await fichier.delete();
        throw const FormatException('empreinte inattendue');
      }
      final lance = await _canal.invokeMethod<bool>('installer', {
        'chemin': fichier.path,
      });
      _etat(
        lance ?? false ? EtatMiseAJour.installation : EtatMiseAJour.disponible,
      );
    } on Object {
      _etat(EtatMiseAJour.echec);
    } finally {
      client.close(force: true);
    }
  }
}
