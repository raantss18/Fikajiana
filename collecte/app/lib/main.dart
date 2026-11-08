import 'package:collecte/app.dart';
import 'package:collecte/catalogue.dart';
import 'package:collecte/collecte.dart';
import 'package:collecte/depot.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final collecte = Collecte(
    depot: DepotAndroid(),
    catalogue: await Catalogue.charger(),
  );
  await collecte.charger();
  runApp(AppCollecte(collecte: collecte));
}
