import 'dart:io';

import 'package:fikajiana/comprendre/carnet.dart';
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
  });

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
    );
  }

  /// Pour l'application : stockage et modèle dans le dossier de l'app.
  static Future<Services> charger() async {
    final dossier = await getApplicationSupportDirectory();
    final modele = ModeleOcr(dossier: '${dossier.path}/modele');
    return Services(
      modele: modele,
      lecteur: LecteurPix2Text(modele),
      moteur: MoteurGiac(),
      courbes: Courbes(fichier: File('${dossier.path}/courbes.json')),
      atelier: Atelier(fichier: File('${dossier.path}/figure.json')),
      carnet: Carnet(dossier: dossier),
    );
  }

  final ModeleOcr modele;
  final Lecteur lecteur;
  final Moteur moteur;
  final Courbes courbes;
  final Atelier atelier;
  final Carnet carnet;
}

class PorteeServices extends InheritedWidget {
  const new({required this.services, required super.child, super.key});

  final Services services;

  static Services de(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PorteeServices>()!.services;

  @override
  bool updateShouldNotify(PorteeServices ancien) => ancien.services != services;
}
