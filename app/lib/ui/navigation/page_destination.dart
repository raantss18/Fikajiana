import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/reglages/reglages.dart';
import 'package:fikajiana/ui/calcul/ecran_feuille.dart';
import 'package:fikajiana/ui/graphe/ecran_graphe.dart';
import 'package:fikajiana/ui/navigation/destination.dart';
import 'package:fikajiana/ui/reglages/ecran_reglages.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Coquille commune à tous les écrans : plein écran, un seul bouton (ADR 0018).
///
/// ← revient à l'écran précédent, Feuille dans le menu revient à l'accueil :
/// ce sont deux gestes distincts (`CLAUDE.md`, règle 9).
class PageDestination extends StatelessWidget {
  const new({required this.destination, super.key});

  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final sombre = PorteeReglages.de(context).support.estSombre;
    final corps = switch (destination) {
      Destination.feuille => const EcranFeuille(),
      Destination.graphe => const EcranGraphe(),
      _ => _EcranABatir(destination: destination),
    };
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (sombre ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
          ),
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            corps,
            Positioned(
              left: 0,
              top: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppEspacement.sm),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (Navigator.of(context).canPop()) ...[
                        BackButton(style: _styleFlottant(context)),
                        const SizedBox(width: AppEspacement.sm),
                      ],
                      _Menu(destination: destination),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

ButtonStyle _styleFlottant(BuildContext context) => IconButton.styleFrom(
  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
  elevation: 2,
);

/// Le seul bouton de navigation : tous les écrans et les réglages.
class _Menu extends StatelessWidget {
  const new({required this.destination});

  final Destination destination;

  void _aller(BuildContext context, Destination cible) {
    final navigateur = Navigator.of(context);
    if (cible == Destination.feuille) {
      navigateur.popUntil((route) => route.isFirst);
    } else if (cible != destination) {
      navigateur.push(RouteDestination(cible));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopupMenuButton<Destination>(
      icon: const Icon(Icons.menu),
      tooltip: l10n.menu,
      style: _styleFlottant(context),
      onSelected: (cible) => _aller(context, cible),
      itemBuilder: (_) => [
        for (final d in Destination.values)
          PopupMenuItem(
            value: d,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(d == destination ? d.iconeActive : d.icone),
              title: Text(d.libelle(l10n)),
              trailing: d == destination ? const Icon(Icons.check) : null,
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          onTap: () =>
              Navigator.of(context)
                  .push(RouteEcran((_) => const EcranReglages())),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.settings_outlined),
            title: Text(l10n.reglages),
          ),
        ),
      ],
    );
  }
}

/// Route sans transition quand l'appareil demande de couper les animations.
class RouteDestination extends RouteEcran {
  new(Destination destination)
    : super((_) => PageDestination(destination: destination));
}

class RouteEcran extends MaterialPageRoute<void> {
  new(WidgetBuilder constructeur) : super(builder: constructeur);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return super.buildTransitions(
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

class _EcranABatir extends StatelessWidget {
  const new({required this.destination});

  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppEspacement.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(destination.icone, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: AppEspacement.sm),
            Text(
              destination.libelle(context.l10n),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppEspacement.sm),
            Text(
              context.l10n.ecranBientot,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
