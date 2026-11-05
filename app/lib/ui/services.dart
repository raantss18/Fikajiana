import 'dart:io';

import 'package:fikajiana/comprendre/stockage_feuille.dart';
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
    this.stockage,
  });

  /// Sans stockage ni modèle.
  factory enMemoire() {
    final modele = ModeleOcr(dossier: null);
    return Services(
      modele: modele,
      lecteur: LecteurPix2Text(modele),
      moteur: MoteurGiac(),
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
      stockage: StockageFeuille(File('${dossier.path}/feuille.json')),
    );
  }

  final ModeleOcr modele;
  final Lecteur lecteur;
  final Moteur moteur;
  final StockageFeuille? stockage;
}

class PorteeServices extends InheritedWidget {
  const new({required this.services, required super.child, super.key});

  final Services services;

  static Services de(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PorteeServices>()!.services;

  @override
  bool updateShouldNotify(PorteeServices ancien) => ancien.services != services;
}
