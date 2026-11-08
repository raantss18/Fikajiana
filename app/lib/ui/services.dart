import 'dart:async';
import 'dart:io';

import 'package:fikajiana/comprendre/carnet.dart';
import 'package:fikajiana/comprendre/classeur.dart';
import 'package:fikajiana/geometrie/atelier.dart';
import 'package:fikajiana/graphe/courbes.dart';
import 'package:fikajiana/guide/essai.dart';
import 'package:fikajiana/moteur/moteur.dart';
import 'package:fikajiana/reconnaissance/classeur_appris.dart';
import 'package:fikajiana/reconnaissance/exemples_personnels.dart';
import 'package:fikajiana/reconnaissance/lecteur.dart';
import 'package:fikajiana/reconnaissance/modele.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

/// Ce dont les écrans ont besoin, en un seul endroit.
class Services {
  new({
    required this.modele,
    required this.lecteur,
    required this.moteur,
    required this.courbes,
    required this.atelier,
    required this.carnet,
    required this.graphes,
    required this.figures,
    ClasseurAppris? classeur,
  }) : classeur = classeur ?? ClasseurAppris(exemples: ExemplesPersonnels()) {
    // Une courbe `C : …` et un objet de la Figure n'ont jamais le même nom.
    courbes.nomsPris = () => atelier.figure.noms;
    atelier.nomsReserves = () => courbes.noms;
    graphes.addListener(() => courbes.changerDeFichier(graphes.fichier));
    figures.addListener(() => atelier.changerDeFichier(figures.fichier));
    // La Figure suit la feuille : un document, c'est les deux (ADR 0032).
    void suivre() {
      graphes.ouvrir(carnet.courante);
      figures.ouvrir(carnet.courante);
    }

    carnet.addListener(suivre);
    suivre();
  }

  /// Sans stockage ni modèle.
  factory enMemoire() {
    final modele = ModeleOcr(dossier: null);
    return Services(
      modele: modele,
      lecteur: LecteurPix2Text(modele),
      moteur: MoteurGiac(),
      courbes: Courbes(),
      atelier: Atelier(),
      carnet: Carnet(),
      graphes: Classeur(),
      figures: Classeur(),
    );
  }

  /// Pour l'application : stockage et modèle dans le dossier de l'app.
  static Future<Services> charger() async {
    final dossier = await getApplicationSupportDirectory();
    const annexes = ['graphes', 'figures'];
    final modele = ModeleOcr(dossier: '${dossier.path}/modele');
    final graphes = Classeur(
      dossier: Directory('${dossier.path}/graphes'),
      ancien: File('${dossier.path}/courbes.json'),
    );
    final figures = Classeur(
      dossier: Directory('${dossier.path}/figures'),
      ancien: File('${dossier.path}/figure.json'),
    );
    final carnet = Carnet(dossier: dossier, annexes: annexes);
    rattacherFiguresAuxFeuilles(dossier, annexes);
    // Les corrections de la personne, sur l'appareil seulement (ADR 0039).
    final exemples = ExemplesPersonnels(
      fichier: File('${dossier.path}/signes/exemples.json'),
    );
    unawaited(exemples.charger());
    return Services(
      classeur: ClasseurAppris(exemples: exemples),
      modele: modele,
      lecteur: LecteurPix2Text(modele),
      moteur: MoteurGiac(),
      courbes: Courbes(fichier: graphes.fichier),
      atelier: Atelier(fichier: figures.fichier),
      carnet: carnet,
      graphes: graphes,
      figures: figures,
    );
  }

  final ModeleOcr modele;
  final Lecteur lecteur;
  final Moteur moteur;
  final Courbes courbes;
  final Atelier atelier;
  final Carnet carnet;
  final Classeur graphes;
  final Classeur figures;

  /// Lit chaque signe : corrections de la personne, puis gabarits (et le
  /// petit modèle quand il sera embarqué, ADR 0038).
  final ClasseurAppris classeur;

  /// Ce que le Guide demande de poser sur la Feuille.
  final essais = EssaiGuide();
}

class PorteeServices extends InheritedWidget {
  const new({required this.services, required super.child, super.key});

  final Services services;

  static Services de(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PorteeServices>()!.services;

  @override
  bool updateShouldNotify(PorteeServices ancien) => ancien.services != services;
}
