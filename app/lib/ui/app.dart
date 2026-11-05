import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/reglages/reglages.dart';
import 'package:fikajiana/ui/navigation/destination.dart';
import 'package:fikajiana/ui/navigation/page_destination.dart';
import 'package:fikajiana/ui/services.dart';
import 'package:fikajiana/ui/theme/theme.dart';
import 'package:flutter/material.dart';

class App extends StatefulWidget {
  const new({this.reglages, this.services, super.key});

  final Reglages? reglages;
  final Services? services;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final Reglages _reglages = widget.reglages ?? Reglages();
  late final Services _services = widget.services ?? Services.enMemoire();

  @override
  Widget build(BuildContext context) {
    return PorteeServices(
      services: _services,
      child: PorteeReglages(
        reglages: _reglages,
        child: ListenableBuilder(
          listenable: _reglages,
          builder: (context, _) => MaterialApp(
            onGenerateTitle: (context) => context.l10n.appTitle,
            theme: AppTheme.clair,
            darkTheme: AppTheme.sombre,
            themeMode: _reglages.support.estSombre
                ? ThemeMode.dark
                : ThemeMode.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PageDestination(destination: Destination.feuille),
          ),
        ),
      ),
    );
  }
}
