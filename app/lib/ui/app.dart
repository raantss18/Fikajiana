import 'dart:async';

import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/reglages/reglages.dart';
import 'package:fikajiana/ui/navigation/destination.dart';
import 'package:fikajiana/ui/navigation/page_destination.dart';
import 'package:fikajiana/ui/reglages/ecran_reglages.dart';
import 'package:fikajiana/ui/services.dart';
import 'package:fikajiana/ui/theme/theme.dart';
import 'package:flutter/material.dart';

class App extends StatefulWidget {
  const new({
    this.reglages,
    this.services,
    this.demanderConsentement = false,
    super.key,
  });

  final Reglages? reglages;
  final Services? services;

  /// Poser une fois la question des dons (ADR 0042) : l'app, pas les tests.
  final bool demanderConsentement;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final Reglages _reglages = widget.reglages ?? Reglages();
  late final Services _services = widget.services ?? Services.enMemoire();
  final _navigation = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    if (widget.demanderConsentement && !_reglages.consentementDemande) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final contexte = _navigation.currentContext;
        if (contexte != null) unawaited(demanderConsentement(contexte));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PorteeServices(
      services: _services,
      child: PorteeReglages(
        reglages: _reglages,
        child: ListenableBuilder(
          listenable: _reglages,
          builder: (context, _) => MaterialApp(
            navigatorKey: _navigation,
            onGenerateTitle: (context) => context.l10n.appTitle,
            theme: AppTheme.clair,
            darkTheme: AppTheme.sombre,
            themeMode: _reglages.support.estSombre
                ? ThemeMode.dark
                : ThemeMode.light,
            // Choisie dans les Réglages, sans redémarrer ; sinon le système.
            locale: switch (_reglages.langue) {
              final code? => Locale(code),
              null => null,
            },
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PageDestination(destination: Destination.feuille),
          ),
        ),
      ),
    );
  }
}
