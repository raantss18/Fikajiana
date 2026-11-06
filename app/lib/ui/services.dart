import 'dart:io';

import 'package:fikajiana/comprendre/carnet.dart';
import 'package:fikajiana/comprendre/classeur.dart';
import 'package:fikajiana/geometrie/atelier.dart';
import 'package:fikajiana/graphe/courbes.dart';
import 'package:fikajiana/moteur/moteur.dart';
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
  }) {
    graphes.addListener(() => courbes.changerDeFichier(graphes.fichier));
    figures.addListener(() => atelier.changerDeFichier(figures.fichier));
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
    final modele = ModeleOcr(dossier: '${dossier.path}/modele');
    final graphes = Classeur(
      dossier: Directory('${dossier.path}/graphes'),
      ancien: File('${dossier.path}/courbes.json'),
    );
    final figures = Classeur(
      dossier: Directory('${dossier.path}/figures'),
      ancien: File('${dossier.path}/figure.json'),
    );
    return Services(
      modele: modele,
      lecteur: LecteurPix2Text(modele),
      moteur: MoteurGiac(),
      courbes: Courbes(fichier: graphes.fichier),
      atelier: Atelier(fichier: figures.fichier),
      carnet: Carnet(dossier: dossier),
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
}

class PorteeServices extends InheritedWidget {
  const new({required this.services, required super.child, super.key});

  final Services services;

  static Services de(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PorteeServices>()!.services;

  @override
  bool updateShouldNotify(PorteeServices ancien) => ancien.services != services;
}
