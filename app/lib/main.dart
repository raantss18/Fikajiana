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
  runApp(
    App(reglages: await Reglages.charger(), services: await Services.charger()),
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
