import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:fikajiana/reconnaissance/ecritures.dart';
import 'package:fikajiana/reglages/reglages.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Ce qu'on dit de l'appareil avec un don : rien de plus (ADR 0042).
typedef InfosAppareil = ({
  String modele,
  Size ecranDp,
  double densite,
  String? versionApp,
});

/// L'état du réseau : connecté, et sans facturation (Wi-Fi).
typedef EtatReseau = ({bool connecte, bool nonFacture});

/// Un POST : le code de réponse.
typedef Poster = Future<int> Function(Uri adresse, String corps);

/// Le résultat d'un essai d'envoi.
enum BilanEnvoi {
  /// Pas de « oui », pas d'adresse, ou rien à donner.
  rien,

  /// Pas de réseau, ou pas de Wi-Fi alors qu'il est demandé.
  horsReseau,

  /// Tout ce qui attendait est parti.
  envoye,

  /// La plateforme ne répond pas comme il faut : on réessaiera.
  aReessayer,
}

/// Envoie les lignes jugées vers la plateforme choisie (ADR 0042), en
/// arrière-plan, par paquets, sans jamais bloquer l'app. Rien ne part sans
/// le « oui » de la personne ni sans adresse. Aucun secret : la plateforme
/// ne connaît qu'un identifiant au hasard, qui sert au retrait.
class EnvoiDons extends ChangeNotifier {
  new({
    required this.ecritures,
    required this.reglages,
    required this.infos,
    required this.reseau,
    Poster? poster,
  }) : _poster = poster ?? posterHttp;

  final Ecritures ecritures;
  final Reglages reglages;
  final Future<InfosAppareil> Function() infos;
  final Future<EtatReseau> Function() reseau;
  final Poster _poster;

  Timer? _minuteur;
  var _enCours = false;
  var _echecs = 0;
  var _ecoute = false;

  /// Première attente après un changement ; puis l'attente double à chaque
  /// échec, jusqu'à une heure.
  static const _premiere = Duration(seconds: 20);
  static const _maximum = Duration(hours: 1);

  /// L'adresse de la plateforme, si elle est sûre : HTTPS, ou HTTP vers
  /// l'appareil lui-même (essais avec `adb reverse`).
  Uri? get adresse => adresseSure(reglages.adressePlateforme);

  static Uri? adresseSure(String texte) {
    final net = texte.trim();
    if (net.isEmpty) return null;
    final uri = Uri.tryParse(net.endsWith('/') ? net : '$net/');
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme == 'https') return uri;
    const locaux = {'localhost', '127.0.0.1', '[::1]', '::1'};
    if (uri.scheme == 'http' && locaux.contains(uri.host)) return uri;
    return null;
  }

  /// Écoute l'écriture et les réglages : un envoi se prépare à chaque
  /// changement.
  void demarrer() {
    if (_ecoute) return;
    _ecoute = true;
    ecritures.addListener(_changement);
    reglages.addListener(_changement);
    _planifier(_premiere);
  }

  void _changement() {
    _echecs = 0;
    _planifier(_premiere);
  }

  void _planifier(Duration attente) {
    _minuteur?.cancel();
    if (!reglages.donner || adresse == null) return;
    if (ecritures.lignesEnAttente == 0 && !_aDesSignesEnAttente) return;
    _minuteur = Timer(attente, () => unawaited(_essayer()));
  }

  bool get _aDesSignesEnAttente => ecritures.liste.any((e) => !e.envoye);

  Future<void> _essayer() async {
    final bilan = await envoyer();
    if (bilan == BilanEnvoi.aReessayer || bilan == BilanEnvoi.horsReseau) {
      _echecs++;
      final secondes = math.min(
        _premiere.inSeconds * math.pow(2, _echecs).toInt(),
        _maximum.inSeconds,
      );
      _minuteur?.cancel();
      _minuteur = Timer(
        Duration(seconds: secondes),
        () => unawaited(_essayer()),
      );
    } else {
      _echecs = 0;
    }
  }

  /// Un essai, tout de suite.
  Future<BilanEnvoi> envoyer() async {
    final cible = adresse;
    if (_enCours || !reglages.donner || cible == null) return BilanEnvoi.rien;
    _enCours = true;
    try {
      final etat = await reseau();
      if (!etat.connecte || (reglages.wifiSeulement && !etat.nonFacture)) {
        return BilanEnvoi.horsReseau;
      }
      final appareil = await infos();
      final paquets = ecritures.dons(
        contributeur: reglages.contributeur,
        modele: appareil.modele,
        ecranDp: appareil.ecranDp,
        densite: appareil.densite,
        versionApp: appareil.versionApp,
      );
      if (paquets.isEmpty) return BilanEnvoi.rien;
      for (final don in paquets) {
        final corps = don.corps;
        if (corps == null) {
          await ecritures.marquerEnvoyes(don.ids);
          continue;
        }
        final int code;
        try {
          code = await _poster(cible.resolve('v1/dons'), corps);
        } on Exception {
          return BilanEnvoi.aReessayer;
        }
        switch (code) {
          case 201:
            await ecritures.marquerEnvoyes(don.ids);
          case 400 || 413 || 415:
            // Refusé tel quel : renvoyer ne servirait à rien. Il reste sur
            // l'appareil pour l'apprentissage local.
            await ecritures.marquerEnvoyes(don.ids);
          case 410:
            // Cet identifiant a été retiré : un nouveau, et on recommence.
            reglages.nouveauContributeur();
            return BilanEnvoi.aReessayer;
          default:
            return BilanEnvoi.aReessayer;
        }
      }
      notifyListeners();
      return BilanEnvoi.envoye;
    } finally {
      _enCours = false;
    }
  }

  /// « Demander le retrait de mes dons » : la plateforme efface ce qui
  /// porte l'identifiant ; les dons suivants en prennent un nouveau.
  Future<bool> demanderRetrait() async {
    final cible = adresse;
    if (cible == null) return false;
    try {
      final code = await _poster(
        cible.resolve('v1/retrait'),
        jsonEncode({'contributeur': reglages.contributeur}),
      );
      if (code != 202) return false;
    } on Exception {
      return false;
    }
    reglages.nouveauContributeur();
    return true;
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    if (_ecoute) {
      ecritures.removeListener(_changement);
      reglages.removeListener(_changement);
    }
    super.dispose();
  }
}

/// Le POST réel : JSON, 30 s au plus, sans cookie ni en-tête d'identité.
Future<int> posterHttp(Uri adresse, String corps) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 30)
    ..userAgent = 'Fikajiana';
  try {
    final requete = await client
        .postUrl(adresse)
        .timeout(const Duration(seconds: 30));
    final octets = utf8.encode(corps);
    // Une longueur annoncée : pas d'envoi par morceaux, que tout récepteur
    // ne lit pas.
    requete
      ..headers.contentType = ContentType.json
      ..contentLength = octets.length
      ..add(octets);
    final reponse = await requete.close().timeout(const Duration(seconds: 30));
    await reponse.drain<void>();
    return reponse.statusCode;
  } on TimeoutException {
    throw const HttpException('délai dépassé');
  } finally {
    client.close(force: true);
  }
}

const _systeme = MethodChannel('fikajiana/systeme');

/// L'appareil vu par Android : modèle, écran, version de l'app.
Future<InfosAppareil> infosAndroid() async {
  final vue = PlatformDispatcher.instance.views.first;
  final version = await _systeme.invokeMethod<String>('version');
  final build = await _systeme.invokeMethod<int>('build');
  return (
    modele: await _systeme.invokeMethod<String>('modele') ?? 'android',
    ecranDp: vue.physicalSize / vue.devicePixelRatio,
    densite: vue.devicePixelRatio,
    versionApp: version == null
        ? null
        : '$version${build == null ? '' : '+$build'}',
  );
}

/// Le réseau vu par Android ; hors Android, pas de réseau.
Future<EtatReseau> reseauAndroid() async {
  try {
    final etat = await _systeme.invokeMapMethod<String, bool>('reseau');
    return (
      connecte: etat?['connecte'] ?? false,
      nonFacture: etat?['nonFacture'] ?? false,
    );
  } on PlatformException {
    return (connecte: false, nonFacture: false);
  } on MissingPluginException {
    return (connecte: false, nonFacture: false);
  }
}
