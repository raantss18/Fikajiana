import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fikajiana/mises_a_jour/signature.dart';
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

/// La version du modèle livrée avec ces constantes. Une version publiée
/// plus grande se propose dans les Réglages (ADR 0064).
const int versionModele = 1;

/// Où l'app cherche `modele.json` et sa signature, à la demande.
const String urlPublicationModele = String.fromEnvironment(
  'MODELE_URL',
  defaultValue:
      'https://github.com/raantss18/Fikajiana/releases/latest/download',
);

/// Un modèle publié par Fikajiana : `modele.json`, signé comme `release.json`.
/// `{"format":1,"modele":{"version":2,"url":"https://…",
/// "fichiers":[{"nom","octets","sha256"}]}}`.
class ModelePublie {
  const new({required this.version, required this.url, required this.fichiers});

  final int version;
  final String url;
  final List<FichierModele> fichiers;

  Map<String, dynamic> versJson() => {
    'version': version,
    'url': url,
    'fichiers': [
      for (final f in fichiers)
        {'nom': f.nom, 'octets': f.octets, 'sha256': f.sha256},
    ],
  };

  /// `null` si la forme n'est pas exactement celle attendue : mêmes noms de
  /// fichiers que le lecteur sait ouvrir, adresse en HTTPS, tailles bornées.
  static ModelePublie? depuisJson(Object? json, {bool httpsSeulement = true}) {
    try {
      final m = json! as Map<String, dynamic>;
      final url = m['url'] as String;
      final adresse = Uri.parse(url);
      if (httpsSeulement && adresse.scheme != 'https') return null;
      final fichiers = [
        for (final f in m['fichiers'] as List<dynamic>)
          FichierModele(
            (f as Map<String, dynamic>)['nom'] as String,
            f['octets'] as int,
            (f['sha256'] as String).toLowerCase(),
          ),
      ];
      final noms = {for (final f in fichiers) f.nom};
      final attendus = {for (final f in fichiersModele) f.nom};
      if (fichiers.length != attendus.length ||
          !noms.containsAll(attendus) ||
          fichiers.any(
            (f) =>
                f.octets <= 0 ||
                f.octets > _octetsMaxParFichier ||
                !RegExp(r'^[0-9a-f]{64}$').hasMatch(f.sha256),
          )) {
        return null;
      }
      return ModelePublie(
        version: m['version'] as int,
        url: url,
        fichiers: fichiers,
      );
    } on Object {
      return null;
    }
  }
}

/// Un fichier de modèle ne dépasse pas 300 Mo (budget de l'appareil).
const int _octetsMaxParFichier = 300 * 1000 * 1000;

/// Le modèle publié, ou `null` si la signature ou le contenu est faux.
Future<ModelePublie?> lireModeleSigne(
  List<int> corps,
  String signatureBase64, {
  String clePublique = clePubliqueBase64,
  bool httpsSeulement = true,
}) async {
  final json = await lireJsonSigne(
    corps,
    signatureBase64,
    clePublique: clePublique,
  );
  if (json == null || json['format'] != 1) return null;
  return ModelePublie.depuisJson(
    json['modele'],
    httpsSeulement: httpsSeulement,
  );
}

enum EtatModele { absent, telechargement, present, echec }

/// La recherche d'une version plus récente du modèle, à la demande.
enum EtatMajModele { repos, recherche, aJour, disponible, installe, echec }

/// Le modèle n'est pas dans l'APK : l'utilisateur le télécharge, une fois, à sa
/// demande, depuis la page de l'auteur (ADR 0016). Rien d'autre ne sort.
class ModeleOcr extends ChangeNotifier {
  new({
    required this.dossier,
    this.url = urlModele,
    this.fichiers = fichiersModele,
    this.urlPublication = urlPublicationModele,
    this.clePublique = clePubliqueBase64,
    this.httpsSeulement = true,
  }) {
    _lireVersionInstallee();
    _etat = _complet ? EtatModele.present : EtatModele.absent;
  }

  /// Pas de dossier : l'app tourne sans modèle (tests, stockage indisponible).
  final String? dossier;
  String url;
  List<FichierModele> fichiers;

  /// Où chercher `modele.json` ; la clé qui doit l'avoir signé.
  final String urlPublication;
  final String clePublique;

  /// Faux seulement dans les tests (serveur local).
  final bool httpsSeulement;

  /// La version installée (ou à installer) : [versionModele] tant qu'aucune
  /// mise à jour n'a été posée.
  int version = versionModele;

  EtatMajModele _maj = EtatMajModele.repos;
  EtatMajModele get maj => _maj;

  /// La version trouvée par [rechercherMiseAJour], plus récente que la nôtre.
  ModelePublie? publie;

  File? get _fiche {
    final d = dossier;
    return d == null ? null : File('$d/version.json');
  }

  /// Une mise à jour posée laisse sa fiche : ses fichiers remplacent ceux
  /// livrés avec l'app.
  void _lireVersionInstallee() {
    final fiche = _fiche;
    if (fiche == null || !fiche.existsSync()) return;
    try {
      final m = ModelePublie.depuisJson(
        jsonDecode(fiche.readAsStringSync()),
        httpsSeulement: httpsSeulement,
      );
      if (m == null || m.version <= versionModele) return;
      version = m.version;
      url = m.url;
      fichiers = m.fichiers;
    } on Object {
      // Fiche abîmée : le modèle livré avec l'app reste la référence.
    }
  }

  void _majEtat(EtatMajModele e) {
    _maj = e;
    notifyListeners();
  }

  /// Cherche, à la demande seulement, un modèle plus récent : `modele.json`
  /// signé par la clé de Fikajiana. Rien n'est envoyé (ADR 0064).
  Future<void> rechercherMiseAJour() async {
    if (_maj == EtatMajModele.recherche || _etat == EtatModele.telechargement) {
      return;
    }
    _majEtat(EtatMajModele.recherche);
    final client = HttpClient();
    try {
      final corps = await _lirePetit(client, '$urlPublication/modele.json');
      final signature = await _lirePetit(
        client,
        '$urlPublication/modele.json.sig',
      );
      final trouve = await lireModeleSigne(
        corps,
        utf8.decode(signature),
        clePublique: clePublique,
        httpsSeulement: httpsSeulement,
      );
      if (trouve == null) {
        _majEtat(EtatMajModele.echec);
      } else if (trouve.version <= version) {
        _majEtat(EtatMajModele.aJour);
      } else {
        publie = trouve;
        _majEtat(EtatMajModele.disponible);
      }
    } on Object {
      _majEtat(EtatMajModele.echec);
    } finally {
      client.close(force: true);
    }
  }

  static Future<List<int>> _lirePetit(HttpClient client, String adresse) async {
    final requete = await client.getUrl(Uri.parse(adresse));
    final reponse = await requete.close().timeout(const Duration(seconds: 20));
    if (reponse.statusCode != HttpStatus.ok) {
      throw HttpException('statut ${reponse.statusCode}');
    }
    final octets = <int>[];
    await for (final m in reponse.timeout(const Duration(seconds: 20))) {
      octets.addAll(m);
      if (octets.length > 64 * 1024) {
        throw const FormatException('description trop grande');
      }
    }
    return octets;
  }

  /// Télécharge le modèle [publie] à côté de l'ancien, vérifie chaque
  /// empreinte, puis remplace : l'ancien reste en place si quoi que ce soit
  /// échoue. Le nouveau modèle sert au prochain démarrage de l'app.
  Future<void> installerMiseAJour() async {
    final d = dossier;
    final nouveau = publie;
    if (d == null || nouveau == null || _etat == EtatModele.telechargement) {
      return;
    }
    final avant = _etat;
    final ancienUrl = url;
    final anciensFichiers = fichiers;
    _etat = EtatModele.telechargement;
    _progression = 0;
    _annule = false;
    notifyListeners();
    final provisoire = Directory('$d.nouveau');
    final client = HttpClient();
    try {
      if (provisoire.existsSync()) provisoire.deleteSync(recursive: true);
      provisoire.createSync(recursive: true);
      url = nouveau.url;
      fichiers = nouveau.fichiers;
      var deja = 0;
      for (final f in nouveau.fichiers) {
        await _telechargerFichier(client, provisoire.path, f, deja);
        deja += f.octets;
      }
      File('${provisoire.path}/version.json')
          .writeAsStringSync(jsonEncode(nouveau.versJson()), flush: true);
      final ancien = Directory(d);
      if (ancien.existsSync()) ancien.deleteSync(recursive: true);
      provisoire.renameSync(d);
      version = nouveau.version;
      publie = null;
      _etat = EtatModele.present;
      _maj = EtatMajModele.installe;
    } on Object {
      url = ancienUrl;
      fichiers = anciensFichiers;
      if (provisoire.existsSync()) provisoire.deleteSync(recursive: true);
      _etat = avant;
      _maj = EtatMajModele.echec;
    } finally {
      client.close(force: true);
    }
    notifyListeners();
  }

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
      // Un modèle mis à jour puis supprimé se retélécharge avec sa fiche.
      if (version > versionModele) {
        File('$d/version.json').writeAsStringSync(
          jsonEncode(
            ModelePublie(
              version: version,
              url: url,
              fichiers: fichiers,
            ).versJson(),
          ),
          flush: true,
        );
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
