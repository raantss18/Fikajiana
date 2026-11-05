import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/ui/navigation/destination.dart';
import 'package:fikajiana/ui/navigation/page_destination.dart';
import 'package:fikajiana/ui/theme/theme.dart';
import 'package:flutter/material.dart';

class App extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: AppTheme.clair,
      darkTheme: AppTheme.sombre,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const PageDestination(destination: Destination.feuille),
    );
  }
}
