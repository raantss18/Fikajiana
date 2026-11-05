import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Un fichier du modèle, tel que publié par son auteur.
class FichierModele {
  const new(this.nom, this.octets, this.sha256);

  final String nom;
  final int octets;
  final String sha256;
}

/// Version et fichiers de Pix2Text-MFR (`models/pix2text-mfr.md`).
const String revisionModele = 'bea257edb2653f2ae413b084f2ac0e8299d08df0';
const String urlModele =
    'https://huggingface.co/breezedeus/pix2text-mfr/resolve/$revisionModele';
const List<FichierModele> fichiersModele = [
  FichierModele(
    'encoder_model.onnx',
    87496990,
    'bd8d5c322792e9ec45793af5569e9748f82a3d728a9e00213dbfc56c1486f37d',
  ),
  FichierModele(
    'decoder_model.onnx',
    30114937,
    'fd0f92d7a012f3dae41e1ac79421aea0ea888b5a66cb3f9a004e424f82f3daed',
  ),
  FichierModele(
    'tokenizer.json',
    39161,
    '3e2ab757277d22639bec28c9d7972e352d3d1dba223051fa674002dc5ab64df3',
  ),
];

enum EtatModele { absent, telechargement, present, echec }

/// Le modèle n'est pas dans l'APK : l'utilisateur le télécharge, une fois, à sa
/// demande, depuis la page de l'auteur (ADR 0016). Rien d'autre ne sort.
class ModeleOcr extends ChangeNotifier {
  new({
    required this.dossier,
    this.url = urlModele,
    this.fichiers = fichiersModele,
  }) {
    _etat = _complet ? EtatModele.present : EtatModele.absent;
  }

  /// Pas de dossier : l'app tourne sans modèle (tests, stockage indisponible).
  final String? dossier;
  final String url;
  final List<FichierModele> fichiers;

  late EtatModele _etat;
  EtatModele get etat => _etat;

  double _progression = 0;
  double get progression => _progression;

  var _annule = false;

  int get octetsTotal => fichiers.fold(0, (s, f) => s + f.octets);

  bool get _complet {
    final d = dossier;
    if (d == null) return false;
    if (File('$d/encoder_model_int8.onnx').existsSync()) return true;
    return fichiers.every((f) {
      final fichier = File('$d/${f.nom}');
      return fichier.existsSync() && fichier.lengthSync() == f.octets;
    });
  }

  void annuler() => _annule = true;

  /// Télécharge et vérifie chaque empreinte. Un fichier faux n'est pas gardé.
  Future<void> telecharger() async {
    final d = dossier;
    if (d == null || _etat == EtatModele.telechargement) return;
    _etat = EtatModele.telechargement;
    _progression = 0;
    _annule = false;
    notifyListeners();
    final client = HttpClient();
    try {
      await Directory(d).create(recursive: true);
      var deja = 0;
      for (final f in fichiers) {
        await _telechargerFichier(client, d, f, deja);
        deja += f.octets;
      }
      _etat = EtatModele.present;
    } on Object {
      _etat = EtatModele.echec;
    } finally {
      client.close(force: true);
    }
    notifyListeners();
  }

  Future<void> _telechargerFichier(
    HttpClient client,
    String d,
    FichierModele f,
    int deja,
  ) async {
    final cible = File('$d/${f.nom}');
    if (cible.existsSync() && cible.lengthSync() == f.octets) return;
    final partiel = File('$d/${f.nom}.partiel');
    final requete = await client.getUrl(Uri.parse('$url/${f.nom}'));
    final reponse = await requete.close();
    if (reponse.statusCode != HttpStatus.ok) {
      throw HttpException('statut ${reponse.statusCode}');
    }
    final sortie = partiel.openWrite();
    final condense = AccumulatorSink<Digest>();
    final empreinte = sha256.startChunkedConversion(condense);
    var recus = 0;
    try {
      await for (final morceau in reponse) {
        if (_annule) throw const HttpException('annulé');
        sortie.add(morceau);
        empreinte.add(morceau);
        recus += morceau.length;
        _progression = (deja + recus) / octetsTotal;
        notifyListeners();
      }
    } finally {
      await sortie.close();
      empreinte.close();
    }
    if (condense.events.single.toString() != f.sha256) {
      await partiel.delete();
      throw const FormatException('empreinte inattendue');
    }
    await partiel.rename(cible.path);
  }

  Future<void> supprimer() async {
    final d = dossier;
    if (d == null) return;
    final repertoire = Directory(d);
    if (repertoire.existsSync()) await repertoire.delete(recursive: true);
    _etat = EtatModele.absent;
    notifyListeners();
  }
}

/// Reçoit le condensat de [sha256].
class AccumulatorSink<T> implements Sink<T> {
  final List<T> events = [];

  @override
  void add(T event) => events.add(event);

  @override
  void close() {}
}
