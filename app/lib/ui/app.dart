import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/reglages/reglages.dart';
import 'package:fikajiana/ui/navigation/destination.dart';
import 'package:fikajiana/ui/navigation/page_destination.dart';
import 'package:fikajiana/ui/theme/theme.dart';
import 'package:flutter/material.dart';

class App extends StatefulWidget {
  const new({this.reglages, super.key});

  final Reglages? reglages;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final Reglages _reglages = widget.reglages ?? Reglages();

  @override
  Widget build(BuildContext context) {
    return PorteeReglages(
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
    );
  }
}
