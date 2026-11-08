import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:collecte/catalogue.dart';
import 'package:collecte/depot.dart';
import 'package:collecte/seance.dart';
import 'package:flutter/foundation.dart';

/// Les réglages de la personne.
class Reglages {
  String prenom = 'Antsa';

  /// L'écran d'accueil (à quoi servent les données, CC0) a été lu.
  bool accueilLu = false;

  /// Le doigt écrit même quand un stylet a déjà servi.
  bool doigtEcrit = false;

  /// Un stylet a déjà touché cet appareil : la main posée n'écrit plus.
  bool styletVu = false;

  /// Validation après ce délai sans trait ; 0 : jamais.
  int delaiMs = 1200;

  /// Combien de fois chaque signe est demandé par séance.
  int repetitions = 3;

  Map<String, Object?> toJson() => {
    'prenom': prenom,
    'accueilLu': accueilLu,
    'doigtEcrit': doigtEcrit,
    'styletVu': styletVu,
    'delaiMs': delaiMs,
    'repetitions': repetitions,
  };

  void lire(Map<String, Object?> j) {
    prenom = j['prenom'] as String? ?? prenom;
    accueilLu = j['accueilLu'] as bool? ?? accueilLu;
    doigtEcrit = j['doigtEcrit'] as bool? ?? doigtEcrit;
    styletVu = j['styletVu'] as bool? ?? styletVu;
    delaiMs = j['delaiMs'] as int? ?? delaiMs;
    repetitions = j['repetitions'] as int? ?? repetitions;
  }
}

/// L'état de l'app : réglages et séance en cours, gardés sur l'appareil.
class Collecte extends ChangeNotifier {
  new({required this.depot, required this.catalogue, Random? hasard})
    : _hasard = hasard ?? Random();

  final Depot depot;
  final Catalogue catalogue;
  final Random _hasard;
  final Reglages reglages = Reglages();
  Seance? seance;

  /// Le chemin du fichier de la séance en cours.
  String? cheminSeance;

  Future<void> charger() async {
    final texte = await depot.lireEtat();
    if (texte != null) {
      final j = jsonDecode(texte) as Map<String, Object?>;
      reglages.lire(j['reglages']! as Map<String, Object?>);
      final s = j['seance'] as Map<String, Object?>?;
      seance = s == null ? null : Seance.etat(s);
    }
    notifyListeners();
  }

  /// Garde l'état et réécrit le fichier de la séance.
  Future<void> sauver() async {
    final s = seance;
    await depot.ecrireEtat(
      jsonEncode({'reglages': reglages.toJson(), 'seance': s?.versEtat()}),
    );
    if (s != null && s.echantillons.isNotEmpty) {
      cheminSeance = await depot.ecrireSeance(
        s.nom,
        jsonEncode(s.versFichier()),
      );
    }
  }

  Future<void> changerReglages(void Function(Reglages r) changement) async {
    changement(reglages);
    notifyListeners();
    await sauver();
  }

  List<Demande> demandesSignes() => [
    for (var i = 0; i < reglages.repetitions; i++)
      for (final s in catalogue.signes) Demande.signe(s.id, s.latex),
  ];

  List<Demande> demandesExpressions() => [
    for (final e in catalogue.expressions) Demande.expression(e),
  ];

  Future<void> commencer({
    required String mode,
    required Size ecran,
    required double densite,
  }) async {
    seance = Seance.nouvelle(
      mode: mode,
      auteur: reglages.prenom.trim().isEmpty
          ? 'anonyme'
          : reglages.prenom.trim(),
      modele: await depot.modele(),
      ecran: ecran,
      densite: densite,
      outil: reglages.styletVu && !reglages.doigtEcrit ? 'stylet' : 'doigt',
      maintenant: DateTime.now(),
      demandes: mode == 'signes' ? demandesSignes() : demandesExpressions(),
      hasard: _hasard,
    );
    cheminSeance = null;
    notifyListeners();
    await sauver();
  }

  /// Enregistre ce qui vient d'être écrit pour la demande en cours.
  Future<void> enregistrer({
    required List<List<PointEncre>> traits,
    required Rect cadre,
    required bool stylet,
    required bool rejete,
  }) async {
    final s = seance;
    if (s == null || s.finie || traits.isEmpty) return;
    if (!s.outilConfirme) s.outil = stylet ? 'stylet' : 'doigt';
    s.ajouter(id: nouvelId(), traits: traits, cadre: cadre, rejete: rejete);
    notifyListeners();
    await sauver();
  }

  /// Le stylet a touché la case : la main n'écrit plus, sauf réglage contraire.
  void styletDetecte() {
    if (reglages.styletVu) return;
    reglages.styletVu = true;
    notifyListeners();
  }

  /// Réécrit la séance en cours et partage toutes les séances enregistrées.
  /// Rend le dossier où elles sont, pour `adb pull`.
  Future<(String, int)> exporter() async {
    await sauver();
    final chemins = await depot.seances();
    if (chemins.isNotEmpty) await depot.partager(chemins);
    return (await depot.dossierSeances(), chemins.length);
  }
}
