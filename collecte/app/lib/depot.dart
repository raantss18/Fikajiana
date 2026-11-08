import 'dart:io';

import 'package:flutter/services.dart';

/// L'appareil, vu par l'app : son modèle, où ranger, comment partager.
abstract class Depot {
  /// Le modèle de l'appareil (`Build.MODEL`), pour le nom des fichiers.
  Future<String> modele();

  /// L'état de l'app (réglages, séance en cours) ;
  /// `null` au premier lancement.
  Future<String?> lireEtat();
  Future<void> ecrireEtat(String texte);

  /// Écrit une séance dans le dossier d'export et rend son chemin complet.
  Future<String> ecrireSeance(String nom, String texte);

  /// Le dossier où vont les séances, lisible par `adb pull`.
  Future<String> dossierSeances();

  /// Les chemins des séances enregistrées, les plus récentes d'abord.
  Future<List<String>> seances();

  /// Ouvre le partage Android avec ces fichiers.
  Future<void> partager(List<String> chemins);
}

/// Le dépôt réel : fichiers de l'app et partage Android (MainActivity.kt).
class DepotAndroid implements Depot {
  static const _canal = MethodChannel('fikajiana_collecte/systeme');
  Map<String, String>? _infos;

  Future<Map<String, String>> get _lesInfos async =>
      _infos ??= (await _canal.invokeMapMethod<String, String>('infos'))!;

  Future<File> get _etat async =>
      File('${(await _lesInfos)['interne']}/etat.json');

  @override
  Future<String> modele() async => (await _lesInfos)['modele'] ?? 'android';

  @override
  Future<String> dossierSeances() async =>
      '${(await _lesInfos)['export']}/seances';

  @override
  Future<String?> lireEtat() async {
    final f = await _etat;
    return f.existsSync() ? await f.readAsString() : null;
  }

  @override
  Future<void> ecrireEtat(String texte) async {
    final f = await _etat;
    // Écrit à côté puis remplace : un arrêt brutal ne laisse pas d'état coupé.
    final provisoire = File('${f.path}.tmp');
    await provisoire.writeAsString(texte, flush: true);
    await provisoire.rename(f.path);
  }

  @override
  Future<String> ecrireSeance(String nom, String texte) async {
    final dossier = Directory(await dossierSeances());
    await dossier.create(recursive: true);
    final f = File('${dossier.path}/$nom');
    final provisoire = File('${f.path}.tmp');
    await provisoire.writeAsString(texte, flush: true);
    await provisoire.rename(f.path);
    return f.path;
  }

  @override
  Future<List<String>> seances() async {
    final dossier = Directory(await dossierSeances());
    if (!dossier.existsSync()) return [];
    return dossier
        .listSync()
        .whereType<File>()
        .map((f) => f.path)
        .where((p) => p.endsWith('.json'))
        .toList()
      ..sort((a, b) => b.compareTo(a));
  }

  @override
  Future<void> partager(List<String> chemins) =>
      _canal.invokeMethod('partager', {'chemins': chemins});
}

/// Un dépôt en mémoire, pour les tests.
class DepotMemoire implements Depot {
  String? etat;
  final Map<String, String> fichiers = {};
  final List<List<String>> partages = [];

  @override
  Future<String> modele() async => 'Essai 1';

  @override
  Future<String> dossierSeances() async => '/memoire/seances';

  @override
  Future<String?> lireEtat() async => etat;

  @override
  Future<void> ecrireEtat(String texte) async => etat = texte;

  @override
  Future<String> ecrireSeance(String nom, String texte) async {
    final chemin = '/memoire/seances/$nom';
    fichiers[chemin] = texte;
    return chemin;
  }

  @override
  Future<List<String>> seances() async =>
      fichiers.keys.toList()..sort((a, b) => b.compareTo(a));

  @override
  Future<void> partager(List<String> chemins) async => partages.add(chemins);
}
