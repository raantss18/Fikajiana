import 'package:fikajiana/reglages/reglages.dart';
import 'package:fikajiana/ui/app.dart';
import 'package:fikajiana/ui/services.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // La feuille va jusqu'au bord, sous les barres du système.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(
    App(reglages: await Reglages.charger(), services: await Services.charger()),
  );
}
