import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/ui/navigation/destination.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:fikajiana/ui/theme/marque.dart';
import 'package:flutter/material.dart';

/// Coquille commune à tous les écrans.
///
/// ← revient à l'écran précédent, l'icône Accueil revient à la Feuille :
/// ce sont deux gestes distincts (`CLAUDE.md`, règle 9).
class PageDestination extends StatelessWidget {
  const new({required this.destination, super.key});

  final Destination destination;

  void _aller(BuildContext context, Destination cible) {
    if (cible == destination) return;
    final navigateur = Navigator.of(context);
    if (cible == Destination.feuille) {
      navigateur.popUntil((route) => route.isFirst);
    } else {
      navigateur.push(RouteDestination(cible));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final compacte = MediaQuery.sizeOf(context).width < AppLargeurs.compacte;
    final corps = _EcranABatir(destination: destination);

    return Scaffold(
      appBar: AppBar(
        title: Text(destination.libelle(l10n)),
        actions: [
          if (destination != Destination.feuille)
            IconButton(
              icon: const Icon(Icons.home_outlined),
              tooltip: l10n.accueil,
              onPressed: () => _aller(context, Destination.feuille),
            ),
        ],
      ),
      body: compacte
          ? corps
          : Row(
              children: [
                NavigationRail(
                  selectedIndex: destination.index,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (i) =>
                      _aller(context, Destination.values[i]),
                  destinations: [
                    for (final d in Destination.values)
                      NavigationRailDestination(
                        icon: Icon(d.icone),
                        selectedIcon: Icon(d.iconeActive),
                        label: Text(d.libelle(l10n)),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: corps),
              ],
            ),
      bottomNavigationBar: compacte
          ? NavigationBar(
              selectedIndex: destination.index,
              onDestinationSelected: (i) =>
                  _aller(context, Destination.values[i]),
              destinations: [
                for (final d in Destination.values)
                  NavigationDestination(
                    icon: Icon(d.icone),
                    selectedIcon: Icon(d.iconeActive),
                    label: d.libelle(l10n),
                  ),
              ],
            )
          : null,
    );
  }
}

/// Route sans transition quand l'appareil demande de couper les animations.
class RouteDestination extends MaterialPageRoute<void> {
  new(Destination destination)
    : super(builder: (_) => PageDestination(destination: destination));

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
            if (destination == Destination.feuille)
              const MarquePi()
            else
              Icon(
                destination.icone,
                color: theme.colorScheme.onSurfaceVariant,
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
