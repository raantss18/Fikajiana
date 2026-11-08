import 'package:fikajiana/dons/envoi_dons.dart';
import 'package:fikajiana/reglages/reglages.dart';
import 'package:fikajiana/ui/app.dart';
import 'package:fikajiana/ui/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(_licencesDesPolices);
  // La feuille va jusqu'au bord, sous les barres du système.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final reglages = await Reglages.charger();
  final services = await Services.charger();
  // Les dons consentis (ADR 0042) : rien ne part sans « oui » ni adresse.
  final ecritures = services.classeur.ecritures;
  if (ecritures != null) {
    services.dons = EnvoiDons(
      ecritures: ecritures,
      reglages: reglages,
      infos: infosAndroid,
      reseau: reseauAndroid,
    )..demarrer();
  }
  runApp(
    App(reglages: reglages, services: services, demanderConsentement: true),
  );
}

/// Les polices sous SIL OFL 1.1 : leur licence doit les accompagner.
Stream<LicenseEntry> _licencesDesPolices() async* {
  for (final (police, fichier) in [
    ('Nunito', 'OFL-Nunito.txt'),
    ('Caveat', 'OFL-Caveat.txt'),
  ]) {
    final texte = await rootBundle.loadString('assets/polices/$fichier');
    yield LicenseEntryWithLineBreaks([police], texte);
  }
}
